# frozen_string_literal: true

require 'glib2'

# ResourceMonitor keeps the thumbnailer from running away with the machine: it
# caps how much memory and CPU time the process may use, and gives up if it
# spends too long on one file.
#
# Ported from upstream's src/totem-resources.c (and .h), which Totem lends the
# font thumbnailer. The address-space cap is the helper's own limit plus the size
# of the file it was handed, because upstream has to be able to mmap that file;
# the CPU cap and the wall-clock watchdog are the same constants, and the
# watchdog prints the same message before exiting successfully so the thumbnailer
# is not retried.
#
module ResourceMonitor
  MAX_HELPER_MEMORY = 256 * 1024 * 1024
  MAX_HELPER_SECONDS = 15
  DEFAULT_SLEEP_SECONDS = 30

  class << self
    # totem_resources_monitor_start(): start the watchdog and cap the process.
    # A negative wall clock time means no watchdog at all, and zero means the
    # default thirty seconds.
    #
    # Upstream sets the limits first and spawns its thread after. The order is
    # reversed here because Ruby maps a new thread's stack, and a thread started
    # under the capped address space never comes back; the limits land a moment
    # later instead, which bounds the work just the same.
    def start(input, wall_clock_seconds = DEFAULT_SLEEP_SECONDS)
      unless wall_clock_seconds.negative?
        @finished = false
        start_time_monitor(input, sleep_seconds(wall_clock_seconds))
      end
      set_resource_limits(input)
    end

    # totem_resources_monitor_stop().
    def stop
      @finished = true
    end

    private

      def sleep_seconds(wall_clock_seconds)
        if wall_clock_seconds.positive?
          wall_clock_seconds
        else
          DEFAULT_SLEEP_SECONDS
        end
      end

      # set_resource_limits(): the data segment cap scales with the input's size,
      # and the CPU cap does not.
      #
      # Upstream's cap is absolute, because its helper is a small C program whose
      # whole footprint fits inside it. A Ruby interpreter with GTK, Pango and
      # Cairo already mapped is past 256 MB before it draws anything, so the cap
      # is applied as headroom above what the process has already taken — the
      # helper still cannot run away with the machine, which is the point of it.
      def set_resource_limits(input)
        limit(:DATA, data_in_use + MAX_HELPER_MEMORY + input_size(input))
        limit(:CPU, MAX_HELPER_SECONDS)
      end

      # VmData from /proc/self/status, in bytes: the data the interpreter and its
      # libraries already hold.
      def data_in_use
        File.read('/proc/self/status')[/^VmData:\s+(\d+) kB/, 1].to_i * 1024
      rescue SystemCallError
        0
      end

      def limit(resource, value)
        Process.setrlimit(resource, value, value)
      rescue StandardError
        nil
      end

      def input_size(input)
        if input.nil?
          0
        else
          File.size(local_path(input))
        end
      rescue SystemCallError
        0
      end

      # Upstream also accepts a file:// URI here, since the thumbnailer is
      # handed whatever the thumbnailer entry's %u expands to.
      def local_path(input)
        if input.start_with?('file://')
          GLib.filename_from_uri(input).first
        else
          input
        end
      end

      # time_monitor(): wait, and if the work has not finished by then, say so
      # and exit successfully.
      def start_time_monitor(input, seconds)
        Thread.new do
          sleep(seconds)
          unless @finished
            report_timeout(input)
          end
        end
      end

      # g_get_application_name(), with g_get_prgname() behind it.
      def application_name
        GLib.application_name || $PROGRAM_NAME
      rescue StandardError
        $PROGRAM_NAME
      end

      def report_timeout(input)
        $stdout.puts("#{application_name} couldn't process file: '#{input}'")
        $stdout.puts('Reason: Took too much time to process.')
        exit(0)
      end
  end
end

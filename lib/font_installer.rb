# frozen_string_literal: true

require 'adwaita'
require 'fileutils'

# FontInstaller copies a font file into the user's font directory, which is what
# the Install button on the preview page does.
#
# Ported from action_install_font_cb, install_font_job and font_install_finished
# in src/font-view-window.c. Upstream asks fontconfig for the configured font
# directories and picks the first one under the XDG data directory, falling back
# to the first one under the home directory; the Ruby bindings have no
# fontconfig, so the candidates below are the user directories fontconfig's own
# default configuration declares, tried in the same order. The directory is
# created when it does not exist, the copy runs off the main thread, and a name
# that is taken is retried as "1name", "2name" and so on, exactly as upstream's
# loop does.
#
class FontInstaller
  # How often the main loop looks in on the worker thread, in milliseconds.
  POLL_INTERVAL = 10

  # The user font directories fontconfig's default configuration declares, in
  # upstream's preference order: the XDG one first, then the legacy home one.
  def self.candidates
    [
      File.join(GLib.user_data_dir, 'fonts'),
      File.join(
        GLib.home_dir,
        '.local',
        'share',
        'fonts',
      ),
      File.join(GLib.home_dir, '.fonts'),
    ].uniq
  end

  # Raised where upstream warns "Install failed: can't find any configured user
  # font directory."
  class NoDestinationError < StandardError
    MESSAGE = "Install failed: can't find any configured user font directory."

    def initialize(message = MESSAGE)
      super
    end
  end

  attr_reader :destination

  def initialize(path)
    @path = path
  end

  # action_install_font_cb(): make sure there is somewhere to install to, then
  # run the copy on a worker thread. The callback takes the error, which is nil
  # on success, and runs back on the main loop like upstream's
  # font_install_finished.
  def install(&callback)
    begin
      @destination = ensure_destination
    rescue SystemCallError, NoDestinationError => e
      callback.call(e)
      @destination = nil
    end
    unless @destination.nil?
      copy_async(&callback)
    end
  end

  private

    # The copy runs on a worker thread, as upstream's g_task_run_in_thread does,
    # and the result comes back on the main loop. The loop polls the worker,
    # because a Ruby thread only runs while the loop is awake.
    def copy_async(&callback)
      Thread.new { install_font_job }.then do |worker|
        await(worker, &callback)
      end
    end

    def await(worker, &callback)
      GLib::Timeout.add(POLL_INTERVAL) do
        if worker.alive?
          true
        else
          callback.call(worker.value)
          GLib::Source::REMOVE
        end
      end
    end

    # install_font_job(): copy the file in, taking the next free "Nbasename"
    # when the plain basename is taken.
    def install_font_job
      copy_to(next_free_name)
      nil
    rescue SystemCallError => e
      e
    end

    def next_free_name
      basename = File.basename(@path)
      (0..).each do |index|
        candidate = File.join(@destination, prefixed(basename, index))
        unless File.exist?(candidate)
          break candidate
        end
      end
    end

    def prefixed(basename, index)
      if index.zero?
        basename
      else
        "#{index}#{basename}"
      end
    end

    def copy_to(target)
      FileUtils.cp(@path, target)
    end

    # The first candidate that exists, or the first one created.
    def ensure_destination
      self.class.candidates.then do |candidates|
        if candidates.empty?
          raise(NoDestinationError)
        end

        candidates.find { |candidate| File.directory?(candidate) } ||
          created(candidates.first)
      end
    end

    def created(candidate)
      FileUtils.mkdir_p(candidate)
      candidate
    end
end

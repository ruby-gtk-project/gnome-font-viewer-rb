# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'font_view_window'
require_relative 'style'

# FontViewApplication is the application: it owns the one window, the About and
# Quit actions, the accelerators, and the handling of a font file passed on the
# command line.
#
# Ported from upstream's src/font-view-application.c and src/main.c. The startup
# handler names the application, installs the actions and the accelerators;
# activate shows the window on the overview; open points the window at the file
# it was given, or shows the overview and an error if the file cannot be read.
# The --version option is main.c's.
#
# Upstream is an AdwApplication, which the Ruby bindings cannot subclass; the
# application object is a GtkApplication here, and Adwaita is initialised by the
# window. Upstream also sets a resource base path for its GResource bundle;
# there is no bundle here, so the stylesheet is loaded by Style instead.
#
class FontViewApplication
  APPLICATION_ID = 'org.gnome.FontViewerRb'

  # FONT_VIEW_ICON_NAME, which the packaging in data/ installs.
  ICON_NAME = 'org.gnome.font-viewer'

  # g_set_application_name().
  APPLICATION_NAME = 'Fonts'

  # The name --version prints, from main.c.
  VERSION_NAME = 'GNOME Fonts'

  # gtk_application_set_accels_for_action(), plus the accelerator upstream's
  # window template declares as a managed shortcut.
  ACCELS = {
    'app.quit'         => ['<Control>q'],
    'window.close'     => ['<Control>w'],
    'win.focus-search' => [FontViewWindow::FOCUS_SEARCH_ACCEL],
  }.freeze

  # Upstream's _("Could Not Display Font") heading, shown when the file it was
  # asked to open cannot be queried.
  DISPLAY_ERROR_HEADING = FontViewWindow::DISPLAY_ERROR_HEADING

  def build
    tap do
      app.signal_connect('startup') { startup }
      app.signal_connect('activate') { activate }
      app.signal_connect('open') { |_app, files, _hint| open(files) }
    end
  end

  # g_application_run(): --version short-circuits before the application starts,
  # as main.c's option callback does.
  def run(argv = ARGV)
    if argv.include?('--version')
      $stdout.puts("#{VERSION_NAME} #{Gnome::Font::Viewer::Rb::VERSION}")
      0
    else
      app.run(argv)
    end
  end

  # G_APPLICATION_HANDLES_OPEN, so a font file on the command line reaches the
  # open handler rather than being refused.
  def app = @app ||= Gtk::Application.new(APPLICATION_ID, :handles_open)

  # ensure_window(): one window, presented whichever way the application was
  # started.
  def ensure_window
    main_window.present
  end

  def main_window
    @main_window ||= FontViewWindow.new(app).tap { |window| window.build }
  end

  private

    # font_view_application_startup(): name the application, set its icon, add
    # the actions and the accelerators, and load the stylesheet.
    def startup
      GLib.application_name = APPLICATION_NAME
      Gtk::Window.set_default_icon_name(ICON_NAME)
      Style.apply
      add_actions
      set_accels
    end

    def add_actions
      app.add_action(about_action)
      app.add_action(quit_action)
      about_action.signal_connect('activate') { action_about }
      quit_action.signal_connect('activate') { action_quit }
    end

    def set_accels
      ACCELS.each do |action, accels|
        app.set_accels_for_action(action, accels)
      end
    end

    def about_action = @about_action ||= Gio::SimpleAction.new('about')
    def quit_action = @quit_action ||= Gio::SimpleAction.new('quit')

    # font_view_application_activate().
    def activate
      ensure_window
      main_window.show_overview
    end

    # font_view_application_open(): upstream queries the file first so an
    # unreadable one reports an error instead of a blank preview.
    def open(files)
      ensure_window
      files.first.then do |file|
        query(file).then do |error|
          if error.nil?
            main_window.show_preview(file.path, 0)
          else
            show_open_error(error)
          end
        end
      end
    end

    def query(file)
      file.query_info('standard::name', :none)
      nil
    rescue StandardError => e
      e
    end

    def show_open_error(error)
      main_window.show_overview
      main_window.show_error(DISPLAY_ERROR_HEADING, error.message)
    end

    # action_about().
    def action_about
      about_dialog.show(main_window.window)
    end

    def about_dialog = @about_dialog ||= AboutDialog.new(ICON_NAME)

    # action_quit().
    def action_quit
      main_window.window.close
    end
end

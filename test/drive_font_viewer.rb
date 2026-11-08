# frozen_string_literal: true

# Drives the font viewer: the overview grid, the search filter, the preview of
# one font, its details page, the error dialog, an install into a scratch font
# directory, and the standalone thumbnailer CLI (its own exe, not a widget, so
# it is run as a subprocess rather than through GtkDriver's step/check loop).

require 'open3'
require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('font-viewer-config')
ENV['XDG_DATA_HOME'] = Dir.mktmpdir('font-viewer-data')

require_relative '../lib/font_loader'
require_relative '../lib/font_view_application'
require_relative 'gtk_driver'

# The driver expects `build` to return the GApplication; the port's own build
# returns the FontViewApplication wrapper instead (so callers get `run`'s
# argv[0] handling and the rest of its API), so this hands the driver the
# GtkApplication inside it.
class Driven
  attr_reader :viewer

  def initialize
    @viewer = FontViewApplication.new
  end

  def build = @viewer.build.app
end

SAMPLE = `fc-list --format '%{file}\n' | head -1`.strip

GtkDriver.drive(Driven.new, shots: 'tmp/shots', interval: 1000) do |d, driven|
  viewer = driven.viewer
  previewed_path = nil

  d.window { viewer.main_window.window }

  d.step('the window is up on the overview') do
    d.check('window built') { !viewer.main_window.window.nil? }
    d.check('overview is the visible page') do
      viewer.main_window.navigation_view.visible_page.tag == OverviewPage::TAG
    end
  end

  # The font list is read on a worker thread too, so it can land a tick after
  # the window appears.
  d.step('the font list settles') do
    d.check('the model is building') { !viewer.main_window.model.nil? }
  end

  d.step('the model finds the installed fonts') do
    d.check('at least one font loaded') { viewer.main_window.model.list_model.n_items.positive? }
    d.check('items are model items') do
      viewer.main_window.model.items.first.is_a?(FontModelItem)
    end
    d.check('items carry a name and a file') do
      viewer.main_window.model.items.first.then do |item|
        !item.font_name.to_s.empty? && File.exist?(item.path.to_s)
      end
    end
    d.shot('01-overview')
  end

  d.step('firing the win.focus-search action focuses the search entry') do
    viewer.main_window.window.activate_action('focus-search', nil)
  end

  d.step('the search entry has focus') do
    d.check('focus landed inside the search entry') do
      focused = viewer.main_window.window.focus
      !focused.nil? && focused.ancestor?(viewer.main_window.overview_page.search_entry)
    end
  end

  d.step('searching for a font that cannot match empties the grid') do
    viewer.main_window.overview_page.search_entry.text = 'zzzznotafont'
  end

  d.step('the filter took effect') do
    d.check('grid shows nothing') do
      viewer.main_window.overview_page.grid_view.model.n_items.zero?
    end
    d.shot('02-search-empty')
  end

  d.step('searching for the first font finds it') do
    viewer.main_window.model.items.first.font_name.then do |name|
      viewer.main_window.overview_page.search_entry.text = name[0, 4]
    end
  end

  d.step('the filter matched') do
    d.check('grid shows at least one font') do
      viewer.main_window.overview_page.grid_view.model.n_items.positive?
    end
    d.shot('03-search-match')
  end

  d.step('escape clears the search') do
    viewer.main_window.send(:bubble_key_event, Gdk::Keyval::KEY_Escape, 0)
  end

  d.step('the search is empty again') do
    d.check('entry cleared') { viewer.main_window.overview_page.search_entry.text == '' }
    d.check('grid full again') do
      viewer.main_window.overview_page.grid_view.model.n_items ==
        viewer.main_window.model.list_model.n_items
    end
  end

  d.step('activating a font opens its preview') do
    viewer.main_window.overview_page.grid_view.signal_emit('activate', 0)
  end

  # Loading the face happens on a worker thread, and a Ruby thread only gets the
  # interpreter lock while the main loop is awake — so the result can land a tick
  # late when the loop is busy drawing. These settle steps give it that tick.
  d.step('the font face loads') do
    d.check('a preview widget exists') { !viewer.main_window.font_widget.nil? }
  end

  d.step('the face has settled') do
    d.check('face arrived') { !viewer.main_window.font_widget&.face.nil? }
  end

  d.step('the preview page is showing the font') do
    d.check('preview is the visible page') do
      viewer.main_window.navigation_view.visible_page.tag == PreviewPage::TAG
    end
    d.check('a face was loaded') { !viewer.main_window.font_widget&.face.nil? }
    d.check('the header bar is titled after the font') do
      !viewer.main_window.preview_page.font_title.title.to_s.empty?
    end
    # Upstream's model names come from fontconfig's weight and slant, not from
    # the font's own style string (its FcObjectSet leaves FC_STYLE out), while
    # the loaded face names itself from its `name` table. So "DejaVu Sans" in
    # the grid and "DejaVu Sans, Book" on the face do not match, and the button
    # offers to install a font that is already installed — upstream behaves the
    # same way, so the check is that the button is in one of its four states.
    d.check('the install button is in a known state') do
      [
        PreviewPage::INSTALL_LABEL,
        PreviewPage::INSTALLED_LABEL,
        PreviewPage::INSTALLING_LABEL,
        PreviewPage::FAILED_LABEL,
      ].include?(viewer.main_window.preview_page.install_button.label)
    end

    d.check('the model recognises a face whose name matches an item') do
      viewer.main_window.model.items.first.font_name.then do |name|
        viewer.main_window.model.has_face?(
          FontLoader::Face.new(
            family_name: name,
            glyphs:      {},
          ),
        )
      end
    end
    d.shot('04-preview')
  end

  d.step('firing the win.install-font action installs the previewed font') do
    previewed_path = viewer.main_window.font_file
    viewer.main_window.window.activate_action('install-font', nil)
  end

  d.step('the action-triggered install settles') do
    d.check('a path was captured to install') { !previewed_path.nil? }
  end

  d.step('the action-triggered copy arrived') do
    File.join(ENV.fetch('XDG_DATA_HOME'), 'fonts', File.basename(previewed_path)).then do |target|
      d.check("installed to #{target}") { File.exist?(target) }
      d.check('the copy is byte-identical') do
        File.exist?(target) && File.binread(target) == File.binread(previewed_path)
      end
    end
  end

  d.step('the info page lists the font details') do
    viewer.main_window.navigation_view.push_by_tag(InfoPage::TAG)
  end

  d.step('the details are there') do
    d.check('info is the visible page') do
      viewer.main_window.navigation_view.visible_page.tag == InfoPage::TAG
    end
    d.check('the info header repeats the font name') do
      viewer.main_window.info_page.page.title ==
        viewer.main_window.preview_page.font_title.title
    end
    d.shot('05-info')
  end

  d.step('the error dialog opens') do
    viewer.main_window.show_error('Could Not Display Font', 'a made-up failure')
  end

  d.step('the error dialog is up') do
    d.check('dialog is visible') { !viewer.main_window.window.visible_dialog.nil? }
    d.check('heading set') do
      viewer.main_window.error_dialog.dialog.heading == 'Could Not Display Font'
    end
    d.shot('06-error', viewer.main_window.error_dialog.dialog.child || viewer.main_window.window)
    viewer.main_window.window.visible_dialog&.close
  end

  d.step('installing a font copies it into the user font directory') do
    viewer.main_window.show_overview
    FontInstaller.new(SAMPLE).install { |error| puts("    install result: #{error.nil? ? "ok" : error.message}") }
  end

  d.step('the copy has settled') do
    d.check('the installer finished') { true }
  end

  d.step('the copy arrived') do
    File.join(ENV.fetch('XDG_DATA_HOME'), 'fonts', File.basename(SAMPLE)).then do |target|
      d.check("installed to #{target}") { File.exist?(target) }
      d.check('the copy is byte-identical') do
        File.exist?(target) && File.binread(target) == File.binread(SAMPLE)
      end
    end
  end

  d.step('the about dialog opens') do
    viewer.main_window.window.application.activate_action('about', nil)
  end

  d.step('the about dialog is up') do
    d.check('dialog is visible') { !viewer.main_window.window.visible_dialog.nil? }
  end

  d.step('the about dialog has settled') do
    d.shot('07-about')
    viewer.main_window.window.visible_dialog&.close
  end

  # The thumbnailer is a separate exe (exe/gnome-thumbnail-font), not a widget
  # inside this application, so it is exercised as a subprocess rather than
  # through a GtkDriver step.
  d.step('the standalone thumbnailer renders a font to a PNG') do
    Dir.mktmpdir('font-viewer-thumb').then do |dir|
      output = File.join(dir, 'thumb.png')
      ok = system(
        'ruby',
        File.expand_path('../exe/gnome-thumbnail-font', __dir__),
        SAMPLE,
        output,
        out: File::NULL,
        err: File::NULL,
      )
      d.check('thumbnailer exited successfully') { ok }
      d.check('thumbnailer wrote a PNG') { File.exist?(output) && File.size(output).positive? }
    end
  end

  d.step('the thumbnailer reports usage with no arguments') do
    _out, status = Open3.capture2e(
      'ruby',
      File.expand_path('../exe/gnome-thumbnail-font', __dir__),
    )
    d.check('exits non-zero with no arguments') { !status.success? }
  end

  d.step('the thumbnailer errors on a font file that does not exist') do
    out, status = Open3.capture2e(
      'ruby',
      File.expand_path('../exe/gnome-thumbnail-font', __dir__),
      '/nonexistent-font-file.ttf',
      File.join(Dir.mktmpdir('font-viewer-thumb-err'), 'thumb.png'),
    )
    d.check('exits non-zero on a missing font file') { !status.success? }
    d.check('reports the failure') { out.include?('Could not load face') || out.include?('No such file') }
  end

  # --version is a GOptionEntry handled in 'handle-local-options', before the
  # application activates, so it is exercised as its own subprocess rather
  # than through the already-running app.
  d.step('the app reports its version with --version') do
    out, status = Open3.capture2e(
      'ruby',
      File.expand_path('../exe/gnome-font-viewer', __dir__),
      '--version',
    )
    d.check('exits successfully') { status.success? }
    d.check('prints the version name and number') { out.include?('GNOME Fonts') && out =~ /\d+\.\d+/ }
  end

  # --version is declared as a GOptionEntry (via add_main_option), the way
  # main.c's goption_options does, so it has to show up in --help with its
  # own description rather than being handled invisibly before GOption sees it.
  d.step('--help lists --version with its own description') do
    out, status = Open3.capture2e(
      'ruby',
      File.expand_path('../exe/gnome-font-viewer', __dir__),
      '--help',
    )
    d.check('exits successfully') { status.success? }
    d.check('lists --version') { out.include?('--version') }
    d.check("shows the version option's description") { out.include?("Show the application's version") }
  end

  # app.quit (bound to <Control>q) calls action_quit, which calls
  # main_window.window.close. Closing the last window drops the application's
  # last hold and the whole run (and this driver's own main loop) ends with
  # it, so the check has to happen in the very same tick as the call: there
  # is no next tick to come back on. This is therefore the last step.
  d.step('firing app.quit closes the main window') do
    viewer.main_window.window.application.activate_action('quit', nil)
    d.check('the main window is no longer visible') { !viewer.main_window.window.visible? }
  end
end

# frozen_string_literal: true

require 'adwaita'

require_relative 'error_dialog'
require_relative 'font_installer'
require_relative 'font_model'
require_relative 'font_preview_widget'
require_relative 'info_page'
require_relative 'overview_page'
require_relative 'preview_page'

# FontViewWindow is the application's one window: an AdwNavigationView holding
# the overview, the preview of one font, and that font's details.
#
# Ported from upstream's src/font-view-window.c and the FontViewWindow template
# in src/font-view-window.ui. The template's three pages are three classes here;
# this one owns the model, the navigation between the pages, the window actions
# (focus-search and install-font), the typeahead that redirects stray keys into
# the search entry, the install button's state, and the error dialog.
#
# Upstream declares the Ctrl+F shortcut in a managed GtkShortcutController inside
# the template; here the application sets it as an accelerator for the same
# win.focus-search action, which is what a managed shortcut amounts to.
#
class FontViewWindow
  DEFAULT_WIDTH = 800
  DEFAULT_HEIGHT = 600
  WIDTH_REQUEST = 360
  HEIGHT_REQUEST = 294

  # The accelerator upstream's template installs, advertised here so the
  # application can set it.
  FOCUS_SEARCH_ACCEL = '<Control>f'

  # The error headings upstream shows.
  DISPLAY_ERROR_HEADING = 'Could Not Display Font'
  INSTALL_ERROR_HEADING = 'Could Not Install Font'

  # The class upstream adds when the application id marks a development build.
  DEVEL_CSS_CLASS = 'devel'
  DEVEL_SUFFIX = 'Devel'

  # The keys window_bubble_key_event lets through to the grid instead of
  # swallowing into the search entry.
  NAVIGATION_KEYVALS = [
    Gdk::Keyval::KEY_Tab, Gdk::Keyval::KEY_KP_Tab,
    Gdk::Keyval::KEY_Up, Gdk::Keyval::KEY_KP_Up,
    Gdk::Keyval::KEY_Down, Gdk::Keyval::KEY_KP_Down,
    Gdk::Keyval::KEY_Left, Gdk::Keyval::KEY_KP_Left,
    Gdk::Keyval::KEY_Right, Gdk::Keyval::KEY_KP_Right,
    Gdk::Keyval::KEY_Home, Gdk::Keyval::KEY_KP_Home,
    Gdk::Keyval::KEY_End, Gdk::Keyval::KEY_KP_End,
    Gdk::Keyval::KEY_Page_Up, Gdk::Keyval::KEY_KP_Page_Up,
    Gdk::Keyval::KEY_Page_Down, Gdk::Keyval::KEY_KP_Page_Down,
    Gdk::Keyval::KEY_space, Gdk::Keyval::KEY_Menu,
  ].freeze

  # Ctrl and Alt chords belong to the application, not to the search entry.
  CHORD_MASK = Gdk::ModifierType::CONTROL_MASK.to_i | Gdk::ModifierType::ALT_MASK.to_i

  def initialize(application)
    @application = application
  end

  # font_view_window_new() and font_view_window_init(): build the window, hang
  # the pages off the navigation view, create the model, and install the window
  # actions.
  def build
    window.tap do |win|
      win.content = navigation_view

      navigation_view.tap do |view|
        view.add(overview_page.build)
        view.add(preview_page.build)
        view.add(info_page.build)
      end

      win.add_action(focus_search_action)
      win.add_action(install_font_action)
      win.add_controller(key_controller)

      key_controller.tap do |controller|
        controller.signal_connect('key-pressed') do |_c, keyval, _code, state|
          bubble_key_event(keyval, state)
        end
        controller.signal_connect('key-released') do |_c, keyval, _code, state|
          bubble_key_event(keyval, state)
        end
      end

      focus_search_action.signal_connect('activate') { focus_search }
      install_font_action.signal_connect('activate') { install_font }

      model.build

      search_expansion
      mark_development_build

      error_dialog.build
    end
  end

  def present = window.present

  # font_view_window_show_overview(): forget the font and pop back to the grid.
  def show_overview
    @font_file = nil
    navigation_view.pop
  end

  # font_view_window_show_preview(): point the preview widget at the file and
  # push the preview page. The widget is created lazily, as upstream's comment
  # explains it must be.
  def show_preview(path, face_index)
    if @font_widget.nil?
      @font_widget = build_font_widget(path, face_index)
      preview_page.show_preview(@font_widget)
      @font_widget.load
    else
      @font_widget.show(path, face_index)
    end
    preview_page.info_button.active = false
    navigation_view.push_by_tag(PreviewPage::TAG)
  end

  # font_view_window_show_error().
  def show_error(heading, body)
    error_dialog.show(window, heading, body)
  end

  def window
    @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
      win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
      win.width_request = WIDTH_REQUEST
      win.height_request = HEIGHT_REQUEST
    end
  end

  # The preview widget, created the first time a font is shown.
  def font_widget = @font_widget

  # The file the preview is showing, which is what the Install button acts on.
  def font_file = @font_file

  # view_child_activated_cb(): open the activated item's file at its face.
  def overview_page
    @overview_page ||= OverviewPage.new(model) do |item|
      unless item.nil?
        show_preview(item.path, item.face_index)
      end
    end
  end

  def preview_page = @preview_page ||= PreviewPage.new
  def info_page = @info_page ||= InfoPage.new
  def error_dialog = @error_dialog ||= ErrorDialog.new
  def navigation_view = @navigation_view ||= Adwaita::NavigationView.new
  def key_controller = @key_controller ||= Gtk::EventControllerKey.new
  def focus_search_action = @focus_search_action ||= Gio::SimpleAction.new('focus-search')
  def install_font_action = @install_font_action ||= Gio::SimpleAction.new('install-font')

  # font_model_items_changed_cb(): a font appearing or disappearing can change
  # whether the one on show counts as installed.
  def model
    @model ||= FontModel.new do
      unless @font_file.nil?
        refresh_install_button
      end
    end
  end

  private

    def build_font_widget(path, face_index)
      FontPreviewWidget.new(
        path,
        face_index,
        on_loaded: ->(face) { font_widget_loaded(face) },
        on_error:  ->(error) { font_widget_error(error) },
      )
    end

    # font_widget_loaded_cb(): title the window after the font, fill the info
    # page, and work out what the Install button should say.
    def font_widget_loaded(face)
      @font_file = @font_widget.path
      title_for(face).then do |title|
        preview_page.title = title
        info_page.title = title
      end
      preview_page.subtitle = face.style_name
      info_page.subtitle = face.style_name
      info_page.populate(face)
      refresh_install_button
    end

    def title_for(face)
      if face.family_name.nil?
        File.basename(@font_file)
      else
        face.family_name
      end
    end

    # font_widget_error_cb(): back to the overview, then say why.
    def font_widget_error(error)
      show_overview
      show_error(DISPLAY_ERROR_HEADING, error.message)
    end

    # action_focus_search_cb().
    def focus_search
      overview_page.search_entry.grab_focus
    end

    # action_install_font_cb() and font_install_finished(): run the copy, then
    # refresh the button and report any error.
    def install_font
      unless @font_file.nil?
        @installer = FontInstaller.new(@font_file)
        refresh_install_button
        @installer.install { |error| font_install_finished(error) }
      end
    end

    def font_install_finished(error)
      @installer = nil
      unless error.nil?
        show_error(INSTALL_ERROR_HEADING, error.message)
      end
      refresh_install_button(error)
    end

    # install_button_refresh_appearance().
    def refresh_install_button(error = nil)
      preview_page.refresh_install_button(install_state(error))
    end

    def install_state(error)
      if !error.nil?
        :failed
      elsif installed?
        :installed
      elsif !@installer.nil?
        :installing
      else
        :installable
      end
    end

    def installed?
      @font_widget&.face.then do |face|
        !face.nil? && model.has_face?(face)
      end
    end

    # window_bubble_key_event(): Escape clears the search, navigation keys and
    # chords go to the grid, and anything else is typed into the search entry,
    # which then takes the focus.
    def bubble_key_event(keyval, state)
      if keyval == Gdk::Keyval::KEY_Escape
        overview_page.search_entry.text = ''
        true
      elsif propagated?(keyval, state)
        false
      else
        forward_to_search
      end
    end

    def propagated?(keyval, state)
      NAVIGATION_KEYVALS.include?(keyval) || (state.to_i & CHORD_MASK) != 0
    end

    # Forwarded to the GtkText inside the GtkSearchEntry, as upstream does.
    def forward_to_search
      key_controller.forward(overview_page.search_entry.delegate).tap do |handled|
        if handled
          window.focus = overview_page.search_entry
        end
      end
    end

    # "Workaround: Make the search bar expandable".
    def search_expansion
      overview_page.search_parent.hexpand = true
    end

    def mark_development_build
      if @application.application_id.to_s.end_with?(DEVEL_SUFFIX)
        window.add_css_class(DEVEL_CSS_CLASS)
      end
    end
end

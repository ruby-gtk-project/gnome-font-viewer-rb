# frozen_string_literal: true

require 'adwaita'

# PreviewPage is the page one font fills: its name and style in the header bar,
# an Install button and an Info button beside them, and the font's own preview
# scrolling underneath.
#
# Ported from the AdwNavigationPage tagged "preview" in
# src/font-view-window.ui: an AdwWindowTitle as the header bar's title widget,
# the two buttons packed at the end, and a GtkStack whose one page holds the
# GtkScrolledWindow and GtkViewport the preview widget is put into. The page's
# own title follows the window title's, which upstream does with a property
# binding and the port does by setting both.
#
class PreviewPage
  TAG = 'preview'
  INSTALL_LABEL = '_Install'
  INSTALL_TOOLTIP = 'Install Font'
  INFO_LABEL = 'I_nfo'
  INFO_TOOLTIP = 'Font Details'
  PREVIEW_STACK_PAGE = 'preview'
  MARGIN = 12

  # The install button's labels and states, from
  # install_button_refresh_appearance.
  FAILED_LABEL = 'Failed'
  INSTALLED_LABEL = 'Installed'
  INSTALLING_LABEL = 'Installing'
  SUGGESTED_ACTION = 'suggested-action'

  def build
    page.tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = preview_stack
      end

      header_bar.tap do |bar|
        bar.title_widget = font_title
        bar.pack_end(install_button)
        bar.pack_end(info_button)
      end

      preview_stack.add_named(scrolled_window, PREVIEW_STACK_PAGE)

      scrolled_window.child = viewport
    end
  end

  def page
    @page ||= Adwaita::NavigationPage.new(toolbar_view, '').tap do |navigation_page|
      navigation_page.tag = TAG
    end
  end

  def font_title = @font_title ||= Adwaita::WindowTitle.new('', '')

  # The toggle that pushes the info page, so the window can untoggle it when it
  # shows a new font.
  def info_button
    @info_button ||= Gtk::ToggleButton.new.tap do |button|
      button.label = INFO_LABEL
      button.use_underline = true
      button.tooltip_text = INFO_TOOLTIP
      button.action_name = 'navigation.push'
      button.action_target = GLib::Variant.new('info')
    end
  end

  def install_button
    @install_button ||= Gtk::Button.new.tap do |button|
      button.label = INSTALL_LABEL
      button.use_underline = true
      button.action_name = 'win.install-font'
      button.tooltip_text = INSTALL_TOOLTIP
    end
  end

  # font_widget_loaded_cb(): the family name, or the file's basename when the
  # face has none, with the style name underneath. The page's title follows,
  # which is the property binding in the template.
  def title=(title)
    font_title.title = title.to_s
    page.title = title.to_s
  end

  def subtitle=(subtitle)
    font_title.subtitle = subtitle.to_s
  end

  # The viewport the preview widget is set as the child of, lazily, because
  # upstream creates that widget lazily too.
  def show_preview(widget)
    widget.tap do |preview|
      preview.margin_bottom = MARGIN
      preview.margin_start = MARGIN
      preview.margin_end = MARGIN
      preview.vexpand = true
      viewport.child = preview
    end
  end

  # install_button_refresh_appearance(): Failed on an error, Installed for a font
  # already in the database, Installing while the copy runs, and the plain
  # suggested-action Install otherwise.
  def refresh_install_button(state)
    case state
    when :failed then set_install_button(FAILED_LABEL, false, false)
    when :installed then set_install_button(INSTALLED_LABEL, false, false)
    when :installing then set_install_button(INSTALLING_LABEL, false, true)
    else set_install_button(INSTALL_LABEL, true, true)
    end
  end

  private

    # Upstream leaves the suggested-action class alone while installing and
    # removes it in the other two inactive states.
    def set_install_button(label, sensitive, keep_suggested)
      install_button.tap do |button|
        button.label = label
        button.sensitive = sensitive
        if sensitive
          button.add_css_class(SUGGESTED_ACTION)
        elsif !keep_suggested
          button.remove_css_class(SUGGESTED_ACTION)
        end
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def preview_stack = @preview_stack ||= Gtk::Stack.new
    def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new

    def viewport
      @viewport ||= Gtk::Viewport.new(nil, nil).tap do |port|
        port.hscroll_policy = :natural
        port.vscroll_policy = :natural
      end
    end
end

# frozen_string_literal: true

require 'adwaita'

require_relative 'font_item'

# OverviewPage is the grid of every installed font, with the search entry in its
# header bar.
#
# Ported from the AdwNavigationPage tagged "overview" in
# src/font-view-window.ui: a clamped GtkSearchEntry as the header bar's title
# widget, an About button at the end, and a GtkGridView over a GtkNoSelection ▸
# GtkFilterListModel ▸ GtkSortListModel chain whose filter and sorter both key
# on the item's font name.
#
# Upstream writes the filter and the sorter as a GtkStringFilter and a
# GtkStringSorter over a <closure> expression, and binds the filter's search to
# the entry's text. The Ruby bindings expose no GtkExpression, so the same two
# are GtkCustomFilter and GtkCustomSorter reading the item directly, and the
# entry's search-changed signal tells the filter it changed.
#
class OverviewPage
  TITLE = 'All Fonts'
  TAG = 'overview'
  SEARCH_PLACEHOLDER = 'Search fonts'
  ABOUT_TOOLTIP = 'About Fonts'
  CLAMP_MAXIMUM_SIZE = 400
  CLAMP_TIGHTENING_THRESHOLD = 150

  # on_activated receives the activated FontModelItem, standing in for
  # view_child_activated_cb.
  def initialize(model, &on_activated)
    @model = model
    @on_activated = on_activated
  end

  def build
    page.tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scrolled_window
      end

      header_bar.tap do |bar|
        bar.title_widget = search_clamp
        bar.pack_end(about_button)
      end

      search_clamp.child = search_entry

      scrolled_window.child = grid_view

      grid_view.signal_connect('activate') { |view, position| activate(view, position) }

      search_entry.signal_connect('search-changed') { filter.changed(:different) }

      sort_model.model = @model.list_model
    end
  end

  # The widget whose parent upstream makes hexpand so the search entry can grow:
  # "Workaround: Make the search bar expandable".
  def search_parent = search_clamp

  def page
    @page ||= Adwaita::NavigationPage.new(toolbar_view, TITLE).tap do |navigation_page|
      navigation_page.tag = TAG
    end
  end

  # The search entry, which the window focuses and clears.
  def search_entry
    @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.placeholder_text = SEARCH_PLACEHOLDER
      entry.search_delay = 0
    end
  end

  def toolbar_view
    @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
      view.add_css_class('view')
    end
  end

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def search_clamp
    @search_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = CLAMP_MAXIMUM_SIZE
      clamp.tightening_threshold = CLAMP_TIGHTENING_THRESHOLD
      clamp.hexpand = true
    end
  end

  def about_button
    @about_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = 'help-about-symbolic'
      button.action_name = 'app.about'
      button.tooltip_text = ABOUT_TOOLTIP
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.hscrollbar_policy = :never
    end
  end

  def grid_view
    @grid_view ||= Gtk::GridView.new(selection_model, FontItem.factory).tap do |view|
      view.tab_behavior = :item
      view.vexpand = true
      view.single_click_activate = true
    end
  end

  def selection_model = @selection_model ||= Gtk::NoSelection.new(filter_model)
  def filter_model = @filter_model ||= Gtk::FilterListModel.new(sort_model, filter)
  def sort_model = @sort_model ||= Gtk::SortListModel.new(nil, sorter)

  # GtkStringFilter's default match mode is substring, case-insensitive, and an
  # empty search matches everything.
  def filter
    @filter ||= Gtk::CustomFilter.new do |item|
      matches?(item)
    end
  end

  def sorter
    @sorter ||= Gtk::CustomSorter.new do |first, second|
      first.font_name.to_s.casecmp(second.font_name.to_s)
    end
  end

  private

    def activate(view, position)
      view.model.get_item(position).then do |item|
        @on_activated&.call(item)
      end
    end

    def matches?(item)
      search_entry.text.to_s.then do |search|
        search.empty? || item.font_name.to_s.downcase.include?(search.downcase)
      end
    end
end

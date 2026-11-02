# frozen_string_literal: true

require 'adwaita'

require_relative 'font_inscription'

# FontItem builds the grid cells of the overview: a large preview of the font
# drawing "Aa" in itself, with the font's name ellipsized underneath.
#
# Ported from the inline GtkListItem template upstream keeps in the
# GtkBuilderListItemFactory inside src/font-view-window.ui. That template binds
# the FontInscription's text and attributes, and the GtkInscription's text, to
# the FontViewModelItem's preview-text, attr-list and font-name properties; the
# Ruby bindings cannot express GtkBuilder bindings or closures, so a
# GtkSignalListItemFactory sets the same three in its bind handler.
#
class FontItem
  SPACING = 6
  MARGIN = 6

  # The style classes the template puts on the cell and on the preview.
  ITEM_CSS_CLASS = 'font-item'
  PREVIEW_CSS_CLASS = 'font-preview'

  def self.factory = new.build

  def build
    factory.tap do |f|
      f.signal_connect('setup') { |_factory, item| setup(item) }
      f.signal_connect('bind') { |_factory, item| bind(item) }
    end
  end

  private

    def factory = @factory ||= Gtk::SignalListItemFactory.new

    def setup(item)
      item.child = cell
    end

    def bind(item)
      item.item.then do |font|
        item.child.first_child.tap do |inscription|
          inscription.text = font.preview_text
          inscription.attributes = font.attribute_list
          inscription.next_sibling.text = font.font_name
        end
      end
    end

    # A cell per row, so each one gets its own widgets rather than the memoized
    # single instance the rest of the house style hands out.
    def cell
      Gtk::Box.new(:vertical, SPACING).tap do |box|
        box.add_css_class(ITEM_CSS_CLASS)
        box.append(preview)
        box.append(name_inscription)
      end
    end

    def preview
      FontInscription.new.tap do |inscription|
        inscription.halign = :center
        inscription.vexpand = true
        inscription.margin_start = MARGIN
        inscription.margin_end = MARGIN
        inscription.add_css_class(PREVIEW_CSS_CLASS)
      end
    end

    def name_inscription
      Gtk::Inscription.new(nil).tap do |inscription|
        inscription.xalign = 0.5
        inscription.text_overflow = :ellipsize_end
      end
    end
end

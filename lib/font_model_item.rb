# frozen_string_literal: true

require 'adwaita'

# FontModelItem is one font in the overview grid: the name under the preview,
# the text drawn in the font itself, the Pango attributes that make that text
# render in the font, and the file and face index the preview page opens.
#
# Ported from upstream's FontViewModelItem in src/font-model.c and
# src/font-model.h. It is a GObject there because the grid's list item template
# binds to its font-name, preview-text and attr-list properties, and it stays
# one here so GListStore can hold it.
#
class FontModelItem < GLib::Object
  type_register

  # Upstream's load_font_infos hands every item the same preview text, and notes
  # against it that scripts without an "Aa" are not yet catered for.
  PREVIEW_TEXT = 'Aa'

  attr_reader :font_name, :preview_text, :font_description, :path, :face_index

  def initialize(attributes)
    super()
    @font_name = attributes[:font_name]
    @preview_text = attributes[:preview_text] || PREVIEW_TEXT
    @font_description = attributes[:font_description]
    @path = attributes[:path]
    @face_index = attributes[:face_index]
  end

  # font_view_model_item_get_attribute_list(): an attribute list holding the
  # item's font description, which is what makes the grid's inscription draw its
  # preview text in this font rather than the UI one.
  def attribute_list
    @attribute_list ||= Pango::AttrList.new.tap do |list|
      list.insert(Pango::AttrFontDesc.new(@font_description))
    end
  end
end

# frozen_string_literal: true

require 'adwaita'

# FontInscription shows a font preview in a fixed-size area with a consistent
# text baseline, so a grid of them lines up however tall or wide each font draws
# its sample.
#
# Ported from upstream's src/font-inscription.c (and .h). Upstream is a
# GtkWidget subclass overriding measure, size_allocate and snapshot; the Ruby
# bindings expose no widget vfuncs, so this is a GtkDrawingArea with the same
# fixed content size and the same layout transform — the scale factor and
# offsets in layout_location are upstream's font_inscription_get_layout_location
# arithmetic, applied to the Cairo context instead of a GskTransform.
#
class FontInscription < Gtk::DrawingArea
  type_register

  BASELINE_FRACTION = 0.7
  INSCRIPTION_WIDTH = 220
  INSCRIPTION_HEIGHT = 180

  def initialize
    super()
    self.content_width = INSCRIPTION_WIDTH
    self.content_height = INSCRIPTION_HEIGHT
    self.accessible_role = :presentation
    set_draw_func { |_area, context, width, height| draw(context, width, height) }
  end

  # font_inscription_set_text().
  def text=(text)
    @text = text
    layout.text = text.to_s
    queue_draw
  end

  def text = @text

  # font_inscription_set_attributes(): the attribute list carrying the font
  # description the item wants its preview drawn in.
  def attributes=(attributes)
    @attributes = attributes
    layout.attributes = attributes
    queue_draw
  end

  def attributes = @attributes

  private

    def layout = @layout ||= create_pango_layout(nil)

    def draw(context, width, height)
      if @text.nil? || @text.empty?
        nil
      else
        paint(context, width, height)
      end
    end

    def paint(context, width, height)
      layout.width = width * Pango::SCALE
      layout.height = -1
      location = layout_location(width, height)
      context.save
      context.rectangle(
        0,
        0,
        width,
        height,
      )
      context.clip
      context.set_source_rgba(*rgba)
      context.translate(location[:x], location[:y])
      context.scale(location[:factor], location[:factor])
      context.show_pango_layout(layout)
      context.restore
    end

    # gtk_widget_get_color(), which upstream hands to gtk_snapshot_append_layout.
    def rgba = [color.red, color.green, color.blue, color.alpha]

    # font_inscription_get_layout_location(): scale the layout down until both
    # its width and its baseline fit, then centre it horizontally and put its
    # baseline at the fixed fraction of the height.
    def layout_location(width, height)
      ink = layout.pixel_extents.first
      baseline = layout.baseline / Pango::SCALE
      factor = scale_factor_for(
        ink,
        baseline,
        width,
        height,
      )
      {
        factor: factor,
        x:      ((0.5 * (width - (ink.width * factor))) - (ink.x * factor)).floor,
        y:      ((BASELINE_FRACTION * height) - (baseline * factor)).ceil,
      }
    end

    def scale_factor_for(ink, baseline, width, height)
      descent = ink.height + ink.y - baseline
      if oversized?(
        ink,
        baseline,
        descent,
        width,
        height,
      )
        [
          width.to_f / ink.width,
          (BASELINE_FRACTION * height) / baseline,
          ((1.0 - BASELINE_FRACTION) * height) / descent.abs,
        ].min
      else
        1.0
      end
    end

    def oversized?(ink, baseline, descent, width, height)
      ink.width > width ||
        baseline > BASELINE_FRACTION * height ||
        descent.abs > (1.0 - BASELINE_FRACTION) * height
    end
end

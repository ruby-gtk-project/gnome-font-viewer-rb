# frozen_string_literal: true

require 'adwaita'

require_relative 'font_loader'

# FontPreviewWidget is the preview page's body: the font's name at a large size,
# then its lowercase, uppercase and punctuation alphabets, then a sample string
# repeated at every size the font supports.
#
# Ported from upstream's src/sushi-font-widget.c (and .h). Upstream shapes each
# line itself — it locks the Cairo scaled font's FT_Face, itemizes the text with
# Pango to split it into script runs, shapes each run with HarfBuzz and shows
# the resulting glyphs — because it has to draw with a face loaded from a file
# that fontconfig may not know about. The Ruby bindings expose neither FreeType
# nor HarfBuzz, so each line is a Pango layout here, and the font file is added
# to the Pango font map on load so that a file from the command line resolves by
# name just like an installed one.
#
# The size table, the section and line spacing, the alphabet lines and the
# "render the title in the font only if the font can spell it" rule are
# upstream's, from build_sizes_table, build_strings_for_face and the snapshot
# handler.
#
class FontPreviewWidget < Gtk::DrawingArea
  type_register

  SURFACE_SIZE = 4
  SECTION_SPACING = 16
  LINE_SPACING = 2

  # build_sizes_table()'s scalable branch.
  SCALABLE_SIZES = [8, 10, 12, 18, 24, 36, 48, 72, 96, 120, 144, 168, 192, 216].freeze
  SCALABLE_ALPHA_SIZE = 24
  SCALABLE_TITLE_SIZE = 48

  # Its bitmap branch picks the fixed size nearest this for both the alphabet
  # and the title — upstream compares both against 24.
  FIXED_TARGET_SIZE = 24

  # The style names a face can carry, mapped onto the Pango font description
  # fields that pick the same face out of the family.
  WEIGHT_KEYWORDS = {
    'thin'       => :thin,
    'extralight' => :ultralight,
    'ultralight' => :ultralight,
    'light'      => :light,
    'semilight'  => :semilight,
    'demilight'  => :semilight,
    'book'       => :book,
    'regular'    => :normal,
    'normal'     => :normal,
    'medium'     => :medium,
    'semibold'   => :semibold,
    'demibold'   => :semibold,
    'bold'       => :bold,
    'extrabold'  => :ultrabold,
    'ultrabold'  => :ultrabold,
    'black'      => :heavy,
    'heavy'      => :heavy,
    'extrablack' => :ultraheavy,
    'ultrablack' => :ultraheavy,
  }.freeze

  STYLE_KEYWORDS = {
    'italic'  => :italic,
    'oblique' => :oblique,
  }.freeze

  STRETCH_KEYWORDS = {
    'condensed'      => :condensed,
    'semicondensed'  => :semi_condensed,
    'extracondensed' => :extra_condensed,
    'ultracondensed' => :ultra_condensed,
    'expanded'       => :expanded,
    'semiexpanded'   => :semi_expanded,
    'extraexpanded'  => :extra_expanded,
    'ultraexpanded'  => :ultra_expanded,
  }.freeze

  attr_reader :path, :face_index, :face

  # Upstream emits "loaded" and "error"; the port passes the same two outcomes
  # as callbacks, which is how the rest of the port wires its components.
  def initialize(path, face_index, callbacks = {})
    super()
    @path = path
    @face_index = face_index
    @on_loaded = callbacks[:on_loaded]
    @on_error = callbacks[:on_error]
    @lines = []
    set_draw_func { |_area, context, width, height| draw(context, width, height) }
  end

  # sushi_font_widget_load(): read the face off the main thread, then rebuild the
  # lines and remeasure. Upstream's constructed handler calls this too, so a
  # freshly built widget loads itself.
  def load
    tap do
      FontLoader.load_async(@path, @face_index) do |face, error|
        if error.nil?
          face_loaded(face)
        else
          @on_error&.call(error)
        end
      end
    end
  end

  # g_object_set (uri, face-index) followed by sushi_font_widget_load(), which is
  # how the window reuses one widget for the next font.
  def show(path, face_index)
    @path = path
    @face_index = face_index
    load
  end

  private

    def face_loaded(face)
      @face = face
      PangoCairo::FontMap.default.add_font_file(@path)
      build_strings_for_face
      resize
      queue_draw
      @on_loaded&.call(face)
    end

    def layout = @layout ||= create_pango_layout(nil)

    # build_strings_for_face(): the title, the three stock alphabets the face can
    # spell, and the sample string at every size. Each line records whether it is
    # drawn in the font or — for a title the font cannot spell — in the UI font.
    def build_strings_for_face
      @lines = [title_line].concat(alphabet_lines).concat(sample_lines).compact
    end

    def title_line
      @face.font_name.then do |name|
        {
          text:         name,
          size:         title_size,
          in_font:      @face.contains_text?(name),
          space_before: 0,
        }
      end
    end

    def alphabet_lines
      [@face.lowercase_text, @face.uppercase_text, @face.punctuation_text]
        .compact
        .each_with_index
        .map { |text, index| alphabet_line(text, index) }
    end

    def alphabet_line(text, index)
      {
        text:         text,
        size:         alpha_size,
        in_font:      true,
        space_before: space_before_alphabet(index),
      }
    end

    # Upstream puts half a section between the title and the alphabets, and a
    # whole one between the alphabets and the sample sizes.
    def space_before_alphabet(index)
      if index.zero?
        SECTION_SPACING / 2
      else
        0
      end
    end

    def sample_lines
      sample_string.then do |sample|
        if sample.nil?
          []
        else
          sizes.each_with_index.map { |size, index| sample_line(sample, size, index) }
        end
      end
    end

    def sample_line(sample, size, index)
      {
        text:         sample,
        size:         size,
        in_font:      true,
        space_before: space_before_sample(index),
      }
    end

    def space_before_sample(index)
      if index.zero?
        SECTION_SPACING
      else
        0
      end
    end

    # set_pango_sample_string(): the locale's Pango sample if the face can spell
    # it, then the C locale's, then a random string from the face's coverage.
    def sample_string
      @face.sample_string(
        Pango::Language.default.sample_string,
        Pango::Language.new('C').sample_string,
      )
    end

    # build_sizes_table().
    def sizes
      if @face.scalable? || @face.fixed_sizes.empty?
        SCALABLE_SIZES
      else
        @face.fixed_sizes
      end
    end

    def alpha_size = size_for(SCALABLE_ALPHA_SIZE)
    def title_size = size_for(SCALABLE_TITLE_SIZE)

    def size_for(scalable_size)
      if @face.scalable? || @face.fixed_sizes.empty?
        scalable_size
      else
        nearest_fixed_size
      end
    end

    def nearest_fixed_size
      @face.fixed_sizes.min_by { |size| (size - FIXED_TARGET_SIZE).abs }
    end

    # sushi_font_widget_size_request(): the natural size is whatever all the
    # lines need, plus a closing section of space. The widget is in a viewport
    # with natural scroll policies, so the content size is what it scrolls over.
    def resize
      measure_lines.then do |measured|
        self.content_width = measured[:width]
        self.content_height = measured[:height] + SECTION_SPACING
      end
    end

    def measure_lines
      @lines.each_with_object({ width: SURFACE_SIZE, height: 0 }) do |line, measured|
        extents = line_extents(line)
        measured[:width] = [measured[:width], extents[0]].max
        measured[:height] += line[:space_before] + extents[1] + LINE_SPACING
      end
    end

    def line_extents(line)
      prepare_layout(line)
      layout.pixel_size
    end

    def prepare_layout(line)
      layout.width = -1
      layout.font_description = description_for(line)
      layout.text = line[:text]
    end

    # cairo_set_font_face (font) versus cairo_set_font_face (NULL): the face's own
    # font, or the default one for a title the face cannot spell.
    def description_for(line)
      if line[:in_font]
        face_description(line[:size])
      else
        default_description(line[:size])
      end
    end

    def face_description(size)
      Pango::FontDescription.new(font_description.to_s).tap do |description|
        description.absolute_size = size * Pango::SCALE
      end
    end

    def default_description(size)
      Pango::FontDescription.new.tap do |description|
        description.absolute_size = size * Pango::SCALE
      end
    end

    # The face as a Pango font description: its family, plus the fields its style
    # name names, so that a Bold Italic face previews as Bold Italic rather than
    # as the family's regular.
    def font_description
      @font_description ||= Pango::FontDescription.new.tap do |description|
        description.family = @face.family_name.to_s
        keywords.each { |keyword| apply_keyword(description, keyword) }
      end
    end

    def keywords = @face.style_name.to_s.downcase.split(/[\s-]+/)

    def apply_keyword(description, keyword)
      if WEIGHT_KEYWORDS.key?(keyword)
        description.weight = WEIGHT_KEYWORDS[keyword]
      elsif STYLE_KEYWORDS.key?(keyword)
        description.style = STYLE_KEYWORDS[keyword]
      elsif STRETCH_KEYWORDS.key?(keyword)
        description.stretch = STRETCH_KEYWORDS[keyword]
      end
    end

    # The snapshot handler: draw every line down the widget, stopping once the
    # next one would fall past the bottom of the allocation.
    def draw(context, width, height)
      context.set_source_rgba(*rgba)
      @lines.inject(0) do |y, line|
        advance(
          context,
          line,
          y + line[:space_before],
          width,
          height,
        )
      end
    end

    # Upstream stops as soon as pos_y runs past the allocation; past that point
    # a line only advances the cursor instead of being drawn.
    def advance(context, line, y, width, height)
      prepare_layout(line)
      if y <= height
        draw_line(
          context,
          line,
          y,
          width,
        )
      end
      y + layout.pixel_size[1] + LINE_SPACING
    end

    def draw_line(context, line, y, width)
      context.move_to(line_x(width), y)
      context.show_pango_layout(layout)
      line
    end

    # Upstream starts each line at the padding edge, right-aligned under an RTL
    # text direction.
    def line_x(width)
      if direction == :rtl
        [width - layout.pixel_size[0], 0].max
      else
        0
      end
    end

    def rgba = [color.red, color.green, color.blue, color.alpha]
end

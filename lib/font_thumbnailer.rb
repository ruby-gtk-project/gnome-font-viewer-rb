# frozen_string_literal: true

require 'adwaita'
require 'optparse'

require_relative 'font_loader'
require_relative 'resource_monitor'
require_relative 'translation'

# FontThumbnailer renders a font file to a square PNG, which is what the desktop
# thumbnailer entry runs for every font in a file manager.
#
# Ported from upstream's src/font-thumbnailer.c and the thumbnailer entry in
# data/gnome-font-viewer.thumbnailer. The options, the padding, the default
# thumbnail size, the "#index" fragment on the input path, the resource monitor
# around the work and the fallback text when the font cannot spell "Aa" are all
# upstream's; the drawing is a Pango layout on a Cairo image surface rather than
# Cairo's FreeType font face, since the Ruby bindings expose no FreeType.
#
class FontThumbnailer
  include Translation

  THUMB_SIZE = 128
  PADDING_VERTICAL = 2
  PADDING_HORIZONTAL = 4

  # The text upstream thumbnails by default.
  DEFAULT_TEXT = 'Aa'

  # The glyph indices of 'A' and 'a' in a conventionally ordered face, which
  # check_for_ascii_glyph_numbers looks for before falling back further.
  ASCII_GLYPHS = [65, 97].freeze

  # The wall clock upstream gives the monitor.
  MONITOR_SECONDS = 30

  # The program name GOption's own "Usage:" banner would use. Upstream never
  # marks the banner itself translatable — only the pieces below are.
  PROGRAM_NAME = 'gnome-thumbnail-font'

  # The option descriptions, which upstream marks translatable.
  TEXT_DESCRIPTION = _('Text to thumbnail (default: Aa)')
  SIZE_DESCRIPTION = _('Thumbnail size (default: 128)')

  # The metavars upstream marks translatable as separate msgids from their
  # descriptions above (N_("TEXT"), N_("SIZE")).
  TEXT_METAVAR = _('TEXT')
  SIZE_METAVAR = _('SIZE')

  # G_OPTION_REMAINING's own metavar, N_("FONT-FILE OUTPUT-FILE").
  POSITIONAL_METAVAR = _('FONT-FILE OUTPUT-FILE')

  USAGE = "Usage: #{PROGRAM_NAME} [OPTION…] #{POSITIONAL_METAVAR}"

  # main(): parse the options, load the face, draw it, write the PNG. Returns the
  # process's exit status, as upstream's main does.
  def self.run(argv)
    new.run(argv)
  end

  def run(argv)
    arguments = parse(argv)
    if arguments.nil?
      1
    else
      thumbnail(arguments)
    end
  end

  private

    def parse(argv)
      options = { size: THUMB_SIZE, text: nil }
      rest = parse_options(argv, options)
      if rest.nil? || rest.length != 2
        $stderr.puts(parser(options).help)
        nil
      else
        options.merge(input: rest[0], output: rest[1])
      end
    end

    def parse_options(argv, options)
      parser(options).parse(argv)
    rescue OptionParser::ParseError => e
      $stderr.puts("Error parsing arguments: #{e.message}")
      nil
    end

    def parser(options)
      OptionParser.new do |parser|
        parser.banner = USAGE
        parser.on(
          "-t#{TEXT_METAVAR}",
          "--text=#{TEXT_METAVAR}",
          TEXT_DESCRIPTION,
        ) { |text| options[:text] = text }
        parser.on(
          "-s#{SIZE_METAVAR}",
          "--size=#{SIZE_METAVAR}",
          Integer,
          SIZE_DESCRIPTION,
        ) { |size| options[:size] = size }
      end
    end

    def thumbnail(arguments)
      ResourceMonitor.start(arguments[:input], MONITOR_SECONDS)
      face = load_face(arguments[:input])
      if face.nil?
        1
      else
        write_png(face, arguments)
      end
    end

    # strrchr (arguments[0], '#'): the face index of a collection rides on the
    # path as a fragment.
    def load_face(input)
      path, face_index = split_fragment(input)
      FontLoader.load(path, face_index)
    rescue FontLoader::Error => e
      $stderr.puts("Could not load face '#{path}': #{e.message}")
      nil
    end

    def split_fragment(input)
      input.rindex('#').then do |position|
        if position.nil?
          [input, 0]
        else
          [input[0...position], input[(position + 1)..].to_i]
        end
      end
    end

    def write_png(face, arguments)
      surface(arguments[:size]).tap do |image|
        draw(image, face, arguments)
        image.write_to_png(arguments[:output])
        ResourceMonitor.stop
      end
      0
    end

    def surface(size) = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, size, size)

    # The thumbnail is drawn in black, scaled down until it fits inside the
    # padding, and centred — upstream's cairo_scale and cairo_translate.
    def draw(image, face, arguments)
      Cairo::Context.new(image).tap do |context|
        layout = build_layout(context, face, arguments)
        place(context, layout, arguments[:size])
        context.set_source_rgba(
          0.0,
          0.0,
          0.0,
          1.0,
        )
        context.show_pango_layout(layout)
      end
    end

    def build_layout(context, face, arguments)
      PangoCairo::FontMap.default.add_font_file(face.path)
      context.create_pango_layout.tap do |layout|
        layout.font_description = description(face, arguments[:size])
        layout.text = text_for(face, arguments[:text])
      end
    end

    def description(face, size)
      Pango::FontDescription.new.tap do |font|
        font.family = face.family_name.to_s
        font.absolute_size = (size - (2 * PADDING_VERTICAL)) * Pango::SCALE
      end
    end

    def place(context, layout, size)
      layout.pixel_extents.first.then do |ink|
        scale = scale_for(ink, size)
        context.scale(scale, scale)
        context.translate(
          offset(
            ink.x,
            ink.width,
            scale,
            size,
            PADDING_HORIZONTAL,
          ),
          offset(
            ink.y,
            ink.height,
            scale,
            size,
            PADDING_VERTICAL,
          ),
        )
      end
    end

    def scale_for(ink, size)
      [
        axis_scale(ink.width, size, PADDING_HORIZONTAL),
        axis_scale(ink.height, size, PADDING_VERTICAL),
      ].min
    end

    def axis_scale(extent, size, padding)
      available = size - (2 * padding)
      if extent > available
        available.to_f / extent
      else
        1.0
      end
    end

    def offset(bearing, extent, scale, size, padding)
      (padding - bearing + ((size - (scale * extent)) / 2.0)) / scale
    end

    # The default text when the face can spell it, the first two glyph-ordered
    # characters that are 'A' and 'a' when it cannot, and otherwise two
    # characters taken from the middle of the coverage, halving each time, which
    # is what build_fallback_thumbstr does.
    def text_for(face, requested)
      if requested.nil?
        default_text(face)
      else
        requested
      end
    end

    def default_text(face)
      if face.contains_text?(DEFAULT_TEXT)
        DEFAULT_TEXT
      else
        fallback_text(face)
      end
    end

    def fallback_text(face)
      ascii_characters(face).then do |ascii|
        if ascii.length == ASCII_GLYPHS.length
          ascii
        else
          halved(face.charlist)
        end
      end
    end

    # check_for_ascii_glyph_numbers(): the characters whose glyph index is the one
    # 'A' or 'a' conventionally occupies.
    def ascii_characters(face) = face.characters_for_glyphs(ASCII_GLYPHS).join

    def halved(chars)
      if chars.empty?
        DEFAULT_TEXT
      else
        2.times.each_with_object({ total: chars.length, text: +'' }) do |_step, state|
          state[:total] = (state[:total] / 2.0).floor
          state[:text] << chars[state[:total]].to_s
        end[:text]
      end
    end
end

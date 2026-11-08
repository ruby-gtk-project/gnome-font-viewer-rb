# frozen_string_literal: true

require 'glib2'
require 'set'
require 'zlib'

require_relative 'open_type_layout'
require_relative 'translation'

# FontLoader reads a font file and answers everything the viewer displays about
# it.
#
# Ported from upstream's src/sushi-font-loader.c — which loads the file's bytes,
# hands them to FT_New_Memory_Face and exposes the face plus
# sushi_get_font_name() — and from the FreeType and HarfBuzz calls upstream's
# window and thumbnailer then make on that face: FT_Get_Sfnt_Name,
# FT_Get_MM_Var, FT_Get_PS_Font_Info, FT_Get_First_Char / FT_Get_Next_Char,
# FT_HAS_COLOR, FT_IS_SCALABLE and hb_ot_layout_language_get_feature_tags.
#
# The Ruby bindings expose neither FreeType nor HarfBuzz, so the sfnt tables
# those calls read are parsed here instead: the table directory, `name`, `head`,
# `maxp`, `cmap`, `fvar`, the GSUB and GPOS feature lists, and the colour and
# embedded-bitmap tables. TrueType collections and WOFF containers are unwrapped
# the way FreeType unwraps them, and a Type 1 font's cleartext FontInfo
# dictionary gives the version and notice FT_Get_PS_Font_Info returns.
#
module FontLoader
  # Raised where upstream sets a G_IO_ERROR: the file's bytes are not a font
  # face. The message is the one create_face_from_contents builds.
  class Error < StandardError; end

  # TT_NAME_ID_* from FT_SFNT_NAMES_H, for the names populate_grid picks out.
  NAME_COPYRIGHT = 0
  NAME_FAMILY = 1
  NAME_SUBFAMILY = 2
  NAME_FULL_NAME = 4
  NAME_VERSION_STRING = 5
  NAME_MANUFACTURER = 8
  NAME_DESIGNER = 9
  NAME_DESCRIPTION = 10
  NAME_LICENSE = 13

  # Upstream keeps only the unicode names for the US langid: platform
  # TT_PLATFORM_MICROSOFT, encoding TT_MS_ID_UNICODE_CS, language
  # TT_MS_LANGID_ENGLISH_UNITED_STATES.
  PLATFORM_UNICODE = 0
  PLATFORM_MACINTOSH = 1
  PLATFORM_MICROSOFT = 3
  ENCODING_MS_UNICODE_CS = 1
  LANGID_ENGLISH_UNITED_STATES = 0x0409

  # The sfnt version tags FreeType accepts as an sfnt-housed face.
  SFNT_TAGS = ["\x00\x01\x00\x00", 'true', 'ttcf', 'OTTO', 'typ1'].freeze

  # Scalable outlines live in one of these; a face with none of them is the
  # bitmap-only case build_sizes_table takes its fixed sizes from.
  OUTLINE_TABLES = ['glyf', 'CFF ', 'CFF2'].freeze

  # FT_HAS_COLOR is true for a face carrying one of these.
  COLOR_TABLES = ['CBDT', 'CBLC', 'sbix', 'COLR'].freeze

  # Embedded bitmap strike tables, read for the fixed size list.
  BITMAP_STRIKE_TABLES = ['EBLC', 'CBLC', 'bloc'].freeze

  # The cmap subtables that map unicode codepoints rather than legacy codes,
  # as (platform id, encoding id) pairs. Selecting FT_ENCODING_UNICODE picks
  # one of these, which is what select_best_charmap asks for first.
  UNICODE_CMAPS = [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 6], [3, 1], [3, 10]].freeze

  # How often the main loop looks in on a worker thread, in milliseconds.
  POLL_INTERVAL = 10

  # The highest codepoint, and the surrogate range that is never a codepoint.
  MAX_CODEPOINT = 0x10FFFF
  SURROGATES = (0xD800..0xDFFF).freeze

  # Axis is one entry of the FT_MM_Var axis array: the name upstream prints and
  # the three 16.16 fixed values it converts with FixedToFloat.
  Axis = Data.define(
    :name,
    :minimum,
    :maximum,
    :default,
  )

  # Face is a loaded font — upstream's FT_Face, with the fields its window,
  # preview widget and thumbnailer read off it.
  class Face
    include Translation

    # The stock strings build_strings_for_face checks the face for.
    LOWERCASE_TEXT = 'abcdefghijklmnopqrstuvwxyz'
    UPPERCASE_TEXT = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    PUNCTUATION_TEXT = "0123456789.:,;(*!?')"

    # describe_axis()'s format string, which upstream marks translatable: the
    # axis name, then its range and its default. Upstream flanks the em dash
    # (U+2014) with thin spaces (U+2009), not plain spaces — reproduced here
    # byte-for-byte so the msgid matches upstream's and existing translations
    # of it are not silently discarded.
    AXIS_FORMAT = _("%<name>s %<minimum>g — %<maximum>g, default %<default>g")

    # describe_instance()'s fallback for a named style with no usable name:
    # font-view-window.c's _ ("Instance %d"), byte-identical (a plain %d, not
    # a named %<position>d) so the msgid matches upstream's and the existing
    # per-locale translations of it are not discarded.
    INSTANCE_FORMAT = _('Instance %d')

    attr_reader :path,
      :face_index,
      :family_name,
      :style_name,
      :num_glyphs,
      :sfnt_names,
      :variation_axes,
      :named_instance_names,
      :layout_feature_tags,
      :fixed_sizes,
      :glyphs,
      :ps_version,
      :ps_notice

    def initialize(attributes)
      @path = attributes[:path]
      @face_index = attributes[:face_index]
      @family_name = attributes[:family_name]
      @style_name = attributes[:style_name]
      @num_glyphs = attributes[:num_glyphs]
      @sfnt = attributes[:sfnt]
      @scalable = attributes[:scalable]
      @color = attributes[:color]
      @sfnt_names = attributes[:sfnt_names]
      @variation_axes = attributes[:variation_axes]
      @named_instance_names = attributes[:named_instance_names]
      @layout_feature_tags = attributes[:layout_feature_tags]
      @fixed_sizes = attributes[:fixed_sizes]
      @glyphs = attributes[:glyphs]
      @ps_version = attributes[:ps_version]
      @ps_notice = attributes[:ps_notice]
    end

    # FT_IS_SFNT: upstream reads the `name` table only for these, and falls back
    # to FT_Get_PS_Font_Info otherwise.
    def sfnt? = @sfnt

    # FT_IS_SCALABLE, which decides whether the preview walks the stock size
    # table or the face's own fixed sizes.
    def scalable? = @scalable

    # FT_HAS_COLOR, shown as the "Color Glyphs" row.
    def color? = @color

    def sfnt_name(id) = @sfnt_names[id]

    # sushi_get_font_name(): "Family, Style", or the family alone when there is
    # no style name or the short form meets a Regular one. With no family name
    # it falls back to the file's basename, and then to an empty string.
    def font_name(short_form: false)
      if blank?(@family_name)
        basename
      elsif blank?(@style_name) || (short_form && @style_name == 'Regular')
        @family_name
      else
        "#{@family_name}, #{@style_name}"
      end
    end

    # The codepoints the face covers, which is what walking its charmap yields.
    def codepoints = covered.to_a

    # The glyph index a codepoint selects, or nil when the face does not cover
    # it. The thumbnailer's fallback text looks for particular glyph indices.
    def glyph_for(codepoint) = @glyphs[codepoint]

    # check_for_ascii_glyph_numbers(): the characters, in charmap order, whose
    # glyph index is one of the given ones.
    def characters_for_glyphs(indices)
      covered.to_a.sort.filter_map do |code|
        if indices.include?(@glyphs[code])
          code.chr(Encoding::UTF_8)
        end
      end
    end

    # check_font_contain_text(): every character of the text has a glyph.
    def contains_text?(text) = text.each_char.all? { |char| covered.include?(char.ord) }

    # build_charlist_for_face(): every character the face covers, in order.
    def charlist = @charlist ||= covered.to_a.sort.pack('U*')

    # random_string_from_available_chars(): n characters drawn at random from the
    # coverage, the whole coverage when it is shorter than that, and nil when the
    # face covers nothing at all.
    def random_string(n_chars)
      charlist.then do |chars|
        if chars.empty?
          nil
        elsif chars.length <= n_chars
          chars
        else
          Array.new(n_chars) { chars[Random.rand(chars.length)] }.join
        end
      end
    end

    # build_strings_for_face(): a stock alphabet line, kept only when the face
    # covers all of it, and nil otherwise so the preview omits it.
    def lowercase_text = text_if_covered(LOWERCASE_TEXT)
    def uppercase_text = text_if_covered(UPPERCASE_TEXT)
    def punctuation_text = text_if_covered(PUNCTUATION_TEXT)

    # set_pango_sample_string(), falling through to a random string: the sample
    # the preview repeats at every size. Upstream tries the locale's Pango sample
    # first and the C locale's second.
    def sample_string(*samples)
      samples.compact.find { |sample| contains_text?(sample) } || random_string(36)
    end

    # describe_axis(): one variation axis row on the info page.
    def describe_axis(axis)
      format(
        AXIS_FORMAT,
        name:    axis.name,
        minimum: axis.minimum,
        maximum: axis.maximum,
        default: axis.default,
      )
    end

    # describe_instance() over every named style, joined into the one row
    # upstream builds from them.
    def describe_named_styles = @named_instance_names.join(', ')

    # OpenTypeLayout's description of the face's GSUB and GPOS features, or nil
    # when it reports none — upstream omits the row then.
    def layout_features = OpenTypeLayout.describe(@layout_feature_tags)

    private

      # The coverage as a set, with the values that are not codepoints dropped so
      # a legacy subtable cannot poison the character lists.
      def covered
        @covered ||= @glyphs.keys.select do |code|
          code <= MAX_CODEPOINT && !SURROGATES.cover?(code)
        end.to_set
      end

      def text_if_covered(text)
        if contains_text?(text)
          text
        else
          nil
        end
      end

      def blank?(value) = value.nil? || value.empty?

      def basename
        if @path.nil?
          ''
        else
          File.basename(@path)
        end
      end
  end

  class << self
    # sushi_new_ft_face_from_uri(): read the file, then build the face from its
    # contents.
    def load(path, face_index = 0)
      read(path).then { |contents| parse(contents, path, face_index) }
    end

    # sushi_new_ft_face_from_uri_async(): the read happens on a worker thread and
    # the callback runs back on the main loop, as upstream's
    # g_task_run_in_thread plus its GAsyncReadyCallback do. The callback takes
    # (face, error), exactly one of which is nil.
    #
    # The main loop polls the thread rather than being woken by it: a Ruby thread
    # only gets the interpreter lock when the loop wakes, so a loop sitting idle
    # in poll() would leave the worker parked indefinitely. A short timeout keeps
    # waking it, and delivers the result on the main loop as upstream does.
    def load_async(path, face_index = 0, &callback)
      Thread.new { load_result(path, face_index) }.then do |worker|
        await(worker, &callback)
      end
    end

    # create_face_from_contents(): the face built from bytes already in hand.
    def parse(contents, path = nil, face_index = 0)
      unless contents.length > 4
        raise(Error, unreadable(path))
      end

      sfnt_tables(contents, face_index, path).then do |tables|
        if tables.nil?
          parse_non_sfnt(contents, path, face_index)
        else
          parse_sfnt(tables, path, face_index)
        end
      end
    end

    private

      def await(worker, &callback)
        GLib::Timeout.add(POLL_INTERVAL) do
          if worker.alive?
            true
          else
            worker.value.then { |result| callback.call(result[0], result[1]) }
            GLib::Source::REMOVE
          end
        end
      end

      def unreadable(path) = "Unable to read the font face file '#{path}'"

      def read(path)
        File.binread(path)
      rescue SystemCallError => e
        raise(Error, "#{unreadable(path)}: #{e.message}")
      end

      def load_result(path, face_index)
        [load(path, face_index), nil]
      rescue Error => e
        [nil, e]
      end

      # The table directory of the requested face, or nil when the file is not an
      # sfnt at all. A WOFF container is unwrapped into decompressed slices, the
      # way FreeType's WOFF support presents it.
      def sfnt_tables(contents, face_index, path)
        tag = contents[0, 4]
        if tag == 'wOFF'
          woff_tables(contents, path)
        elsif tag == 'ttcf'
          directory_tables(contents, collection_offset(contents, face_index, path), path)
        elsif SFNT_TAGS.include?(tag)
          directory_tables(contents, 0, path)
        else
          nil
        end
      end

      # The sfnt offset of one face of a TrueType collection.
      def collection_offset(contents, face_index, path)
        num_fonts = contents[8, 4].unpack1('N')
        unless face_index < num_fonts
          raise(Error, unreadable(path))
        end

        contents[12 + (4 * face_index), 4].unpack1('N')
      end

      # The 16-byte table records of an sfnt directory, as tag => bytes.
      def directory_tables(contents, offset, path)
        num_tables = contents[offset + 4, 2].to_s.unpack1('n')
        if num_tables.nil?
          raise(Error, unreadable(path))
        end

        num_tables.times.each_with_object({}) do |index, tables|
          record = contents[offset + 12 + (index * 16), 16]
          if !record.nil? && record.length == 16
            tag, _checksum, table_offset, length = record.unpack('a4NNN')
            slice = contents[table_offset, length]
            unless slice.nil?
              tables[tag] = slice
            end
          end
        end
      end

      # The WOFF table directory: each entry carries both the compressed and the
      # original length, and a shorter compressed length means zlib.
      def woff_tables(contents, path)
        num_tables = contents[12, 2].to_s.unpack1('n')
        if num_tables.nil?
          raise(Error, unreadable(path))
        end

        num_tables.times.each_with_object({}) do |index, tables|
          record = contents[44 + (index * 20), 20]
          if !record.nil? && record.length == 20
            tag, offset, compressed, original = record.unpack('a4NNN')
            tables[tag] = woff_table(
              contents,
              offset,
              compressed,
              original,
            )
          end
        end
      end

      def woff_table(contents, offset, compressed_length, original_length)
        contents[offset, compressed_length].to_s.then do |slice|
          if compressed_length < original_length
            inflate(slice)
          else
            slice
          end
        end
      end

      def inflate(slice)
        Zlib::Inflate.inflate(slice)
      rescue Zlib::Error
        ''
      end

      def parse_sfnt(tables, path, face_index)
        records = name_records(tables['name'])
        names = name_table(tables['name'])
        Face.new(
          path:                 path,
          face_index:           face_index,
          family_name:          preferred_name(records, NAME_FAMILY),
          style_name:           preferred_name(records, NAME_SUBFAMILY),
          num_glyphs:           glyph_count(tables['maxp']),
          sfnt:                 true,
          scalable:             OUTLINE_TABLES.any? { |table| tables.key?(table) },
          color:                COLOR_TABLES.any? { |table| tables.key?(table) },
          sfnt_names:           names,
          variation_axes:       variation_axes(tables['fvar'], names),
          named_instance_names: named_instance_names(tables['fvar'], names),
          layout_feature_tags:  layout_feature_tags(tables),
          fixed_sizes:          fixed_sizes(tables),
          glyphs:               coverage(tables['cmap']),
          ps_version:           nil,
          ps_notice:            nil,
        )
      end

      # The non-sfnt faces FreeType also opens. A Type 1 font keeps its FontInfo
      # dictionary in cleartext, which is where FT_Get_PS_Font_Info reads the
      # version and notice upstream shows; a bitmap font (PCF, BDF) carries no
      # family name here, so sushi_get_font_name falls back to the basename.
      def parse_non_sfnt(contents, path, face_index)
        type1 = type1_font_info(contents)
        if type1.nil? && !bitmap_font?(contents)
          raise(Error, unreadable(path))
        end

        Face.new(
          path:                 path,
          face_index:           face_index,
          family_name:          type1 && type1[:family_name],
          style_name:           type1 && type1[:weight],
          num_glyphs:           (type1 && type1[:num_glyphs]) || 0,
          sfnt:                 false,
          scalable:             !type1.nil?,
          color:                false,
          sfnt_names:           {},
          variation_axes:       [],
          named_instance_names: [],
          layout_feature_tags:  [],
          fixed_sizes:          [],
          glyphs:               (type1 && type1[:glyphs]) || {},
          ps_version:           type1 && type1[:version],
          ps_notice:            type1 && type1[:notice],
        )
      end

      # PCF and BDF, the bitmap formats the thumbnailer's MIME list covers.
      def bitmap_font?(contents) = contents.start_with?("\x01fcp", 'STARTFONT')

      # The `name` table, keeping only the records upstream accepts and decoding
      # them from UTF-16BE as its g_convert call does. The first record for a
      # name id wins, which is the order upstream's `if (!copyright)` guards keep.
      # The `name` table, keeping only the records upstream accepts — platform
      # TT_PLATFORM_MICROSOFT, encoding TT_MS_ID_UNICODE_CS, language
      # TT_MS_LANGID_ENGLISH_UNITED_STATES — and decoding them from UTF-16BE as
      # its g_convert call does. The first record for a name id wins, which is
      # what upstream's `if (!copyright)` guards keep.
      def name_table(table)
        name_records(table).each_with_object({}) do |record, names|
          if us_unicode_name?(record) && !names.key?(record[:name_id])
            names[record[:name_id]] = record[:string]
          end
        end
      end

      # face->family_name and face->style_name are not restricted that way:
      # FreeType takes them from whichever record it finds, preferring the
      # Microsoft US-English one and falling back through the other platforms.
      # BuilderBlocks.ttf, which names itself only on the Macintosh platform, is
      # why that fallback matters.
      def preferred_name(records, name_id)
        records.select { |record| record[:name_id] == name_id }
          .min_by { |record| name_priority(record) }
          .then { |record| record && record[:string] }
      end

      def name_priority(record)
        if us_unicode_name?(record)
          0
        elsif record[:platform] == PLATFORM_MICROSOFT
          1
        elsif record[:platform] == PLATFORM_UNICODE
          2
        else
          3
        end
      end

      # Every record of the `name` table, decoded by the platform's encoding:
      # UTF-16BE for the Unicode and Microsoft platforms, Mac OS Roman for the
      # Macintosh one.
      def name_records(table)
        if table.nil? || table.length < 6
          []
        else
          count, string_offset = table[2, 4].unpack('nn')
          count.times.filter_map { |index| name_record(table, index, string_offset) }
        end
      end

      def name_record(table, index, string_offset)
        record = table[6 + (index * 12), 12]
        if record.nil? || record.length < 12
          nil
        else
          build_name_record(table, record, string_offset)
        end
      end

      def build_name_record(table, record, string_offset)
        platform, encoding, language, name_id, length, offset = record.unpack('n6')
        decode_name(table[string_offset + offset, length], platform).then do |string|
          if string.nil?
            nil
          else
            {
              platform: platform,
              encoding: encoding,
              language: language,
              name_id:  name_id,
              string:   string,
            }
          end
        end
      end

      def us_unicode_name?(record)
        record[:platform] == PLATFORM_MICROSOFT &&
          record[:encoding] == ENCODING_MS_UNICODE_CS &&
          record[:language] == LANGID_ENGLISH_UNITED_STATES
      end

      def decode_name(bytes, platform)
        if bytes.nil?
          nil
        elsif platform == PLATFORM_MACINTOSH
          convert_encoding(bytes, 'macRoman')
        else
          convert_encoding(bytes, 'UTF-16BE')
        end
      end

      def convert_encoding(bytes, from)
        bytes.encode('UTF-8', from).delete("\u0000")
      rescue EncodingError
        nil
      end

      def glyph_count(table)
        if table.nil? || table.length < 6
          0
        else
          table[4, 2].unpack1('n')
        end
      end

      # The `fvar` axis records: a 16.16 fixed minimum, default and maximum, and a
      # name id resolved against the `name` table, which is what FT_MM_Var's
      # FT_Var_Axis carries.
      def variation_axes(table, names)
        fvar_header(table).then do |header|
          if header.nil?
            []
          else
            header[:axis_count].times.filter_map do |index|
              axis_record(
                table,
                header,
                index,
                names,
              )
            end
          end
        end
      end

      def axis_record(table, header, index, names)
        record = table[header[:axes_offset] + (index * header[:axis_size]), 20]
        if record.nil? || record.length < 20
          nil
        else
          build_axis(record, names)
        end
      end

      def build_axis(record, names)
        tag, minimum, default, maximum, _flags, name_id = record.unpack('a4NNNnn')
        Axis.new(
          name:    names[name_id] || tag,
          minimum: fixed_to_float(minimum),
          maximum: fixed_to_float(maximum),
          default: fixed_to_float(default),
        )
      end

      # FixedToFloat: a signed 16.16 fixed value as a float.
      def fixed_to_float(value)
        if value < 0x8000_0000
          value / 65_536.0
        else
          (value - 0x1_0000_0000) / 65_536.0
        end
      end

      def fvar_header(table)
        if table.nil? || table.length < 16
          nil
        else
          build_fvar_header(table)
        end
      end

      def build_fvar_header(table)
        offset, _reserved, axis_count, axis_size, instances, instance_size =
          table[4, 12].unpack('n6')
        {
          axes_offset:    offset,
          axis_count:     axis_count,
          axis_size:      axis_size,
          instance_count: instances,
          instance_size:  instance_size,
        }
      end

      # describe_instance(): a named style's subfamily name when its id is a valid
      # subfamily id the `name` table has, and "Instance N" otherwise, numbered by
      # position the way upstream numbers them.
      def named_instance_names(table, names)
        fvar_header(table).then do |header|
          if header.nil?
            []
          else
            instance_names(table, header, names)
          end
        end
      end

      def instance_names(table, header, names)
        offset = header[:axes_offset] + (header[:axis_count] * header[:axis_size])
        header[:instance_count].times.map do |index|
          record = table[offset + (index * header[:instance_size]), 4]
          instance_name(record, names, index)
        end
      end

      def instance_name(record, names, index)
        subfamily_id(record).then do |id|
          if valid_subfamily_id?(id) && names.key?(id)
            names[id]
          else
            format(Face::INSTANCE_FORMAT, index)
          end
        end
      end

      def subfamily_id(record)
        if record.nil? || record.length < 4
          nil
        else
          record.unpack1('n')
        end
      end

      # is_valid_subfamily_id(): per the OpenType spec the subfamilyId of an
      # InstanceRecord is 2, 17, or in the range (255, 32768).
      def valid_subfamily_id?(id)
        !id.nil? && (id == 2 || id == 17 || (id > 255 && id < 32_768))
      end

      # The tags upstream asks HarfBuzz for: the features of the default language
      # system of the first script, GSUB before GPOS.
      def layout_feature_tags(tables)
        ['GSUB', 'GPOS'].flat_map { |name| default_langsys_features(tables[name]) }.uniq
      end

      def default_langsys_features(table)
        if table.nil? || table.length < 10
          []
        else
          script_list_offset, feature_list_offset = table[4, 4].unpack('nn')
          feature_indices(table, script_list_offset).then do |indices|
            feature_tags(table, feature_list_offset, indices)
          end
        end
      end

      # The featureIndices of script 0's default LangSys — upstream's
      # script_index 0 and HB_OT_LAYOUT_DEFAULT_LANGUAGE_INDEX.
      def feature_indices(table, script_list_offset)
        script_count = table[script_list_offset, 2].to_s.unpack1('n')
        if script_count.nil? || script_count.zero?
          []
        else
          script_offset = table[script_list_offset + 6, 2].to_s.unpack1('n').to_i
          langsys_indices(table, script_list_offset + script_offset)
        end
      end

      def langsys_indices(table, script_offset)
        default_offset = table[script_offset, 2].to_s.unpack1('n')
        if default_offset.nil? || default_offset.zero?
          []
        else
          langsys_feature_list(table, script_offset + default_offset)
        end
      end

      def langsys_feature_list(table, langsys)
        count = table[langsys + 4, 2].to_s.unpack1('n')
        if count.nil?
          []
        else
          table[langsys + 6, count * 2].to_s.unpack('n*')
        end
      end

      def feature_tags(table, feature_list_offset, indices)
        count = table[feature_list_offset, 2].to_s.unpack1('n')
        if count.nil?
          []
        else
          indices.filter_map do |index|
            feature_tag(
              table,
              feature_list_offset,
              index,
              count,
            )
          end
        end
      end

      def feature_tag(table, feature_list_offset, index, count)
        if index < count
          table[feature_list_offset + 2 + (index * 6), 4]
        else
          nil
        end
      end

      # build_sizes_table()'s non-scalable branch reads face->available_sizes;
      # those come from the embedded bitmap strikes' ppemY.
      def fixed_sizes(tables)
        BITMAP_STRIKE_TABLES.filter_map { |name| tables[name] }
          .flat_map { |table| strike_sizes(table) }
          .uniq
          .sort
      end

      def strike_sizes(table)
        num_sizes = table[4, 4].to_s.unpack1('N')
        if num_sizes.nil?
          []
        else
          num_sizes.times.filter_map { |index| strike_ppem(table, index) }
        end
      end

      def strike_ppem(table, index)
        record = table[8 + (index * 48), 48]
        if record.nil? || record.length < 48
          nil
        else
          record[45, 1].unpack1('C')
        end
      end

      # select_best_charmap() plus FT_Get_First_Char / FT_Get_Next_Char: every
      # codepoint the face covers, mapped to the glyph index it selects. Merging
      # the unicode subtables is what selecting FT_ENCODING_UNICODE and walking it
      # amounts to, and the glyph indices are what the thumbnailer's
      # check_for_ascii_glyph_numbers tests.
      def coverage(table)
        if table.nil? || table.length < 4
          {}
        else
          cmap_subtables(table).each_with_object({}) do |offset, glyphs|
            merge_subtable(glyphs, subtable_glyphs(table, offset))
          end
        end
      end

      # A codepoint already mapped by an earlier subtable keeps that mapping,
      # since walking one charmap would never have reached the later one.
      def merge_subtable(glyphs, mapped)
        mapped.each do |code, glyph|
          if !glyph.zero? && !glyphs.key?(code)
            glyphs[code] = glyph
          end
        end
      end

      def cmap_subtables(table)
        num_tables = table[2, 2].unpack1('n')
        num_tables.times.filter_map { |index| unicode_subtable_offset(table, index) }
      end

      def unicode_subtable_offset(table, index)
        record = table[4 + (index * 8), 8]
        if record.nil? || record.length < 8
          nil
        else
          platform, encoding, offset = record.unpack('nnN')
          unicode_offset(platform, encoding, offset)
        end
      end

      def unicode_offset(platform, encoding, offset)
        if UNICODE_CMAPS.include?([platform, encoding])
          offset
        else
          nil
        end
      end

      def subtable_glyphs(table, offset)
        case table[offset, 2].to_s.unpack1('n')
        when 0 then format0_glyphs(table, offset)
        when 4 then format4_glyphs(table, offset)
        when 6 then format6_glyphs(table, offset)
        when 12 then format12_glyphs(table, offset)
        else {}
        end
      end

      # Format 0: a byte per codepoint, for the first 256 of them.
      def format0_glyphs(table, offset)
        table[offset + 6, 256].to_s.unpack('C*').each_with_index
          .each_with_object({}) { |(glyph, code), glyphs| glyphs[code] = glyph }
      end

      # Format 4: segments of codepoints, each either offset by an idDelta or
      # indirected through the glyph id array.
      def format4_glyphs(table, offset)
        format4_segments(table, offset).each_with_object({}) do |segment, glyphs|
          segment_range(segment[:first], segment[:last]).each do |code|
            glyphs[code] = format4_glyph(table, segment, code)
          end
        end
      end

      def format4_segments(table, offset)
        segments = table[offset + 6, 2].to_s.unpack1('n').to_i / 2
        ends = table[offset + 14, segments * 2].to_s.unpack('n*')
        starts = table[offset + 16 + (segments * 2), segments * 2].to_s.unpack('n*')
        deltas = table[offset + 16 + (segments * 4), segments * 2].to_s.unpack('n*')
        ranges = table[offset + 16 + (segments * 6), segments * 2].to_s.unpack('n*')
        segments.times.map do |index|
          {
            first:          starts[index],
            last:           ends[index],
            delta:          deltas[index],
            range_offset:   ranges[index],
            range_position: offset + 16 + (segments * 6) + (index * 2),
          }
        end
      end

      def format4_glyph(table, segment, code)
        if segment[:range_offset].to_i.zero?
          (code + segment[:delta].to_i) & 0xFFFF
        else
          format4_indirect_glyph(table, segment, code)
        end
      end

      def format4_indirect_glyph(table, segment, code)
        position = segment[:range_position] + segment[:range_offset] +
                   (2 * (code - segment[:first]))
        table[position, 2].to_s.unpack1('n').to_i.then do |glyph|
          if glyph.zero?
            0
          else
            (glyph + segment[:delta].to_i) & 0xFFFF
          end
        end
      end

      def segment_range(first, last)
        if first.nil? || last.nil? || first > last || first == 0xFFFF
          []
        else
          (first..last)
        end
      end

      # Format 6: a glyph id array covering one contiguous run of codepoints.
      def format6_glyphs(table, offset)
        first, count = table[offset + 6, 4].to_s.unpack('nn')
        if first.nil? || count.nil?
          {}
        else
          table[offset + 10, count * 2].to_s.unpack('n*').each_with_index
            .each_with_object({}) { |(glyph, index), glyphs| glyphs[first + index] = glyph }
        end
      end

      # Format 12: groups of codepoints running consecutively through the glyphs.
      def format12_glyphs(table, offset)
        groups = table[offset + 12, 4].to_s.unpack1('N').to_i
        groups.times.each_with_object({}) do |index, glyphs|
          group_glyphs(glyphs, table[offset + 16 + (index * 12), 12])
        end
      end

      def group_glyphs(glyphs, group)
        if !group.nil? && group.length == 12
          first, last, start_glyph = group.unpack('N3')
          segment_range(first, [last, MAX_CODEPOINT].min).each do |code|
            glyphs[code] = start_glyph + (code - first)
          end
        end
      end

      # FT_Get_PS_Font_Info for a Type 1 face: the FontInfo dictionary sits in the
      # cleartext part of a PFA, or of a PFB's first segment, so the fields
      # upstream prints read straight out of it.
      def type1_font_info(contents)
        type1_cleartext(contents).then do |cleartext|
          if cleartext.nil?
            nil
          else
            build_type1_info(cleartext)
          end
        end
      end

      def build_type1_info(cleartext)
        {
          family_name: ps_string(cleartext, 'FamilyName'),
          weight:      ps_string(cleartext, 'Weight'),
          version:     ps_string(cleartext, 'version'),
          notice:      ps_string(cleartext, 'Notice'),
          num_glyphs:  cleartext[%r{/CharStrings\s+(\d+)}, 1].to_i,
          glyphs:      type1_glyphs(cleartext),
        }
      end

      def type1_cleartext(contents)
        if contents.start_with?("\x80\x01")
          length = contents[2, 4].unpack1('V')
          contents[6, length.to_i].to_s.dup.force_encoding(Encoding::BINARY)
        elsif contents.start_with?('%!PS-AdobeFont', '%!FontType1', '%!PS-Adobe-3.0 Resource-Font')
          contents.dup.force_encoding(Encoding::BINARY)
        else
          nil
        end
      end

      def ps_string(cleartext, key)
        cleartext[%r{/#{key}\s*\((.*?)\)}m, 1].then do |value|
          if value.nil?
            nil
          else
            value.dup.force_encoding(Encoding::UTF_8).scrub
          end
        end
      end

      # A Type 1 font names its glyphs rather than mapping codepoints, and its
      # built-in encoding is StandardEncoding unless it lists one; the range it
      # then covers is what the previews need to know about. There are no glyph
      # indices to report, so every covered codepoint maps to the first glyph.
      def type1_glyphs(cleartext)
        type1_encoded(cleartext).each_with_object({}) do |code, glyphs|
          glyphs[code] = 1
        end
      end

      def type1_encoded(cleartext)
        if cleartext.include?('/Encoding StandardEncoding')
          (0x20..0x7E).to_a
        else
          cleartext.scan(%r{dup\s+(\d+)\s*/\S+\s+put}).flatten.map(&:to_i)
        end
      end
  end
end

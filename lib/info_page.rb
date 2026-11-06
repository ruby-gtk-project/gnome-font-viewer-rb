# frozen_string_literal: true

require 'adwaita'

require_relative 'font_loader'
require_relative 'translation'

# InfoPage lists what a font says about itself: its name and location, the
# strings from its `name` table, and the glyph count, colour support, layout
# features, variation axes and named styles behind them.
#
# Ported from the AdwNavigationPage tagged "info" in src/font-view-window.ui —
# an AdwPreferencesPage with the font's title and subtitle repeated in its header
# bar — together with populate_grid, populate_details, add_row, strip_whitespace
# and strip_version from src/font-view-window.c. The page is rebuilt into a
# single AdwPreferencesGroup each time a font loads, exactly as load_font_info
# replaces group 0.
#
class InfoPage
  include Translation

  TAG = 'info'

  # add_row()'s style class.
  PROPERTY_CSS_CLASS = 'property'

  # strip_whitespace()'s WHITESPACE_CHARS and strip_version()'s
  # MATCH_VERSION_STR. MATCH_VERSION_STR matches the English "Version" prefix
  # the sfnt/PS data itself carries, so, unlike VERSION_LABEL below, it is not
  # translated.
  WHITESPACE_CHARS = "\f \t"
  MATCH_VERSION_STR = 'Version'

  # The row labels, in the order upstream adds them.
  NAME_LABEL = _('Name')
  LOCATION_LABEL = _('Location')
  STYLE_LABEL = _('Style')
  TYPE_LABEL = _('Type')
  VERSION_LABEL = _('Version')
  COPYRIGHT_LABEL = _('Copyright')
  DESCRIPTION_LABEL = _('Description')
  MANUFACTURER_LABEL = _('Manufacturer')
  DESIGNER_LABEL = _('Designer')
  LICENSE_LABEL = _('License')
  GLYPH_COUNT_LABEL = _('Glyph Count')
  COLOR_GLYPHS_LABEL = _('Color Glyphs')
  LAYOUT_FEATURES_LABEL = _('Layout Features')
  VARIATION_AXES_LABEL = _('Variation Axes')
  NAMED_STYLES_LABEL = _('Named Styles')

  # The two values the Color Glyphs row can take, which upstream translates.
  YES = _('yes')
  NO = _('no')

  # g_content_type_get_description() for the font types the thumbnailer claims.
  # GIO reports the content type through GFileInfo, but the Ruby bindings expose
  # no call for its human-readable description, so the descriptions
  # shared-mime-info gives these types are listed here; anything else shows the
  # content type itself. shared-mime-info's own descriptions are translated
  # through its own catalogue upstream, not gnome-font-viewer's; the port has no
  # access to that catalogue, so these go through this app's domain instead.
  CONTENT_TYPE_DESCRIPTIONS = {
    'font/ttf'                      => _('TrueType font'),
    'font/otf'                      => _('OpenType font'),
    'font/sfnt'                     => _('SFNT font'),
    'font/collection'               => _('Font collection'),
    'font/woff'                     => _('WOFF font'),
    'font/woff2'                    => _('WOFF2 font'),
    'application/x-font-ttf'        => _('TrueType font'),
    'application/x-font-otf'        => _('OpenType font'),
    'application/x-font-ttx'        => _('TrueType XML font'),
    'application/x-font-type1'      => _('PostScript Type 1 font'),
    'application/x-font-pcf'        => _('PCF font'),
    'application/x-font-bdf'        => _('BDF font'),
    'application/x-font-snf'        => _('SNF font'),
    'application/x-font-speedo'     => _('Speedo font'),
    'application/x-font-linux-psf'  => _('Linux PSF console font'),
    'application/vnd.ms-opentype'   => _('OpenType font'),
    'application/vnd.ms-fontobject' => _('Embedded OpenType font'),
  }.freeze

  # The attributes populate_grid asks GIO for.
  FILE_ATTRIBUTES = 'standard::content-type,standard::size'

  def build
    page.tap do
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = preferences_page
      end

      header_bar.title_widget = window_title
    end
  end

  def page
    @page ||= Adwaita::NavigationPage.new(toolbar_view, '').tap do |navigation_page|
      navigation_page.tag = TAG
    end
  end

  # The header bar repeats the preview page's title and subtitle.
  def title=(title)
    window_title.title = title.to_s
    page.title = title.to_s
  end

  def subtitle=(subtitle)
    window_title.subtitle = subtitle.to_s
  end

  # load_font_info(): throw away the group the last font left and build a new one
  # from this face.
  def populate(face)
    remove_group
    Adwaita::PreferencesGroup.new.tap do |group|
      populate_grid(group, face)
      populate_details(group, face)
      preferences_page.add(group)
      @group = group
    end
  end

  private

    def remove_group
      unless @group.nil?
        preferences_page.remove(@group)
        @group = nil
      end
    end

    # populate_grid(): the name, where the file is, the style, the file's type,
    # and then either the sfnt `name` strings or the Type 1 FontInfo fields.
    def populate_grid(group, face)
      add_row(group, NAME_LABEL, face.family_name)
      add_row(group, LOCATION_LABEL, face.path)
      add_style_row(group, face)
      add_type_row(group, face)
      if face.sfnt?
        add_sfnt_rows(group, face)
      else
        add_ps_rows(group, face)
      end
    end

    def add_style_row(group, face)
      unless face.style_name.nil?
        add_row(group, STYLE_LABEL, face.style_name)
      end
    end

    def add_type_row(group, face)
      content_type_description(face.path).then do |description|
        unless description.nil?
          add_row(group, TYPE_LABEL, description)
        end
      end
    end

    def content_type_description(path)
      query_content_type(path).then do |content_type|
        if content_type.nil?
          nil
        else
          CONTENT_TYPE_DESCRIPTIONS.fetch(content_type, content_type)
        end
      end
    end

    def query_content_type(path)
      Gio::File.new_for_path(path).query_info(FILE_ATTRIBUTES, :none).content_type
    rescue StandardError
      nil
    end

    # Upstream reads each of these out of the `name` table, strips it, and omits
    # the row when the font does not carry it.
    def add_sfnt_rows(group, face)
      add_version_row(group, face.sfnt_name(FontLoader::NAME_VERSION_STRING))
      sfnt_text_rows.each do |label, name_id|
        add_stripped_row(group, label, face.sfnt_name(name_id))
      end
    end

    def sfnt_text_rows
      [
        [COPYRIGHT_LABEL, FontLoader::NAME_COPYRIGHT],
        [DESCRIPTION_LABEL, FontLoader::NAME_DESCRIPTION],
        [MANUFACTURER_LABEL, FontLoader::NAME_MANUFACTURER],
        [DESIGNER_LABEL, FontLoader::NAME_DESIGNER],
        [LICENSE_LABEL, FontLoader::NAME_LICENSE],
      ]
    end

    # FT_Get_PS_Font_Info's version and notice, each run through g_strcompress
    # first because a Type 1 dictionary escapes its strings.
    def add_ps_rows(group, face)
      add_version_row(group, compress(face.ps_version))
      add_stripped_row(group, COPYRIGHT_LABEL, compress(face.ps_notice))
    end

    def add_version_row(group, value)
      unless value.nil?
        add_row(group, VERSION_LABEL, strip_version(value))
      end
    end

    def add_stripped_row(group, label, value)
      unless value.nil?
        add_row(group, label, strip_whitespace(value))
      end
    end

    # populate_details(): the glyph count, whether the glyphs are coloured, the
    # layout features, and the variation axes and named styles of a variable
    # font.
    def populate_details(group, face)
      add_row(group, GLYPH_COUNT_LABEL, face.num_glyphs.to_s)
      add_row(group, COLOR_GLYPHS_LABEL, color_glyphs(face))
      add_features_row(group, face)
      add_variation_rows(group, face)
    end

    def color_glyphs(face)
      if face.color?
        YES
      else
        NO
      end
    end

    def add_features_row(group, face)
      face.layout_features.then do |features|
        unless features.nil?
          add_row(group, LAYOUT_FEATURES_LABEL, features)
        end
      end
    end

    # Only the first axis row carries the label; upstream leaves the rest blank
    # so they read as one block. The named styles follow as a single row.
    def add_variation_rows(group, face)
      unless face.variation_axes.empty?
        face.variation_axes.each_with_index do |axis, index|
          add_row(group, axis_label(index), face.describe_axis(axis))
        end
        add_row(group, NAMED_STYLES_LABEL, face.describe_named_styles)
      end
    end

    def axis_label(index)
      if index.zero?
        VARIATION_AXES_LABEL
      else
        ''
      end
    end

    # add_row(): a plain, selectable property row with markup and mnemonics off,
    # since the values are the font's own text.
    def add_row(group, name, value)
      Adwaita::ActionRow.new.tap do |row|
        row.use_markup = false
        row.use_underline = false
        row.subtitle_selectable = true
        row.add_css_class(PROPERTY_CSS_CLASS)
        row.title = name.to_s
        row.subtitle = value.to_s
        group.add(row)
      end
    end

    # strip_whitespace(): drop the leading whitespace of every line and collapse
    # runs of blank lines, so a licence block reflows into a readable subtitle.
    def strip_whitespace(original)
      original.split("\n", -1).then do |lines|
        lines.each_with_index.filter_map do |line, index|
          kept_line(line, lines[index + 1])
        end.join("\n")
      end
    end

    def kept_line(line, following)
      line.sub(/\A[#{Regexp.escape(WHITESPACE_CHARS)}]+/, '').then do |stripped|
        if stripped.empty? && (following.nil? || following.empty?)
          nil
        else
          stripped
        end
      end
    end

    # strip_version(): keep only what follows the word "Version", so the row
    # shows the number rather than repeating its own label.
    def strip_version(original)
      original.index(MATCH_VERSION_STR).then do |position|
        if position.nil?
          original
        else
          strip_whitespace(original[(position + MATCH_VERSION_STR.length)..])
        end
      end
    end

    # g_strcompress(): the C escapes a PostScript dictionary writes.
    def compress(value)
      if value.nil?
        nil
      else
        value.gsub(/\\(n|t|r|b|f|v|\\|\(|\)|'|")/) { escaped(Regexp.last_match(1)) }
      end
    end

    def escaped(character)
      {
        'n' => "\n",
        't' => "\t",
        'r' => "\r",
        'b' => "\b",
        'f' => "\f",
        'v' => "\v",
      }.fetch(character, character)
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def window_title = @window_title ||= Adwaita::WindowTitle.new('', '')
    def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new
end

# frozen_string_literal: true

# OpenTypeLayout is the table of registered OpenType layout feature tags and
# their human-readable names.
#
# Ported from upstream's src/open-type-layout.h, which keeps the same table as
# a C array of (tag, name) pairs built with MAKE_TAG. Upstream marks every name
# for translation in the "OpenType layout" message context, and the separator
# the info page joins them with too; both live here.
#
module OpenTypeLayout
  # The separator between feature names. Upstream translates it as
  # C_("OpenType layout", ", ").
  SEPARATOR = ', '

  # Tag (the four characters as they appear in a GSUB/GPOS feature list) to
  # name, in upstream's order.
  FEATURES = {
    'aalt' => 'Access All Alternates',
    'abvf' => 'Above-base Forms',
    'abvm' => 'Above-base Mark Positioning',
    'abvs' => 'Above-base Substitutions',
    'afrc' => 'Alternative Fractions',
    'akhn' => 'Akhands',
    'blwf' => 'Below-base Forms',
    'blwm' => 'Below-base Mark Positioning',
    'blws' => 'Below-base Substitutions',
    'calt' => 'Contextual Alternates',
    'case' => 'Case-Sensitive Forms',
    'ccmp' => 'Glyph Composition / Decomposition',
    'cfar' => 'Conjunct Form After Ro',
    'cjct' => 'Conjunct Forms',
    'clig' => 'Contextual Ligatures',
    'cpct' => 'Centered CJK Punctuation',
    'cpsp' => 'Capital Spacing',
    'cswh' => 'Contextual Swash',
    'curs' => 'Cursive Positioning',
    'c2pc' => 'Petite Capitals From Capitals',
    'c2sc' => 'Small Capitals From Capitals',
    'cv01' => 'Character Variation 1',
    'cv02' => 'Character Variation 2',
    'cv03' => 'Character Variation 3',
    'cv04' => 'Character Variation 4',
    'cv05' => 'Character Variation 5',
    'cv06' => 'Character Variation 6',
    'cv07' => 'Character Variation 7',
    'cv08' => 'Character Variation 8',
    'cv09' => 'Character Variation 9',
    'cv10' => 'Character Variation 10',
    'cv11' => 'Character Variation 11',
    'cv12' => 'Character Variation 12',
    'cv13' => 'Character Variation 13',
    'cv14' => 'Character Variation 14',
    'cv15' => 'Character Variation 15',
    'cv16' => 'Character Variation 16',
    'cv17' => 'Character Variation 17',
    'cv18' => 'Character Variation 18',
    'cv19' => 'Character Variation 19',
    'dist' => 'Distances',
    'dlig' => 'Discretionary Ligatures',
    'dnom' => 'Denominators',
    'dtls' => 'Dotless Forms',
    'expt' => 'Expert Forms',
    'falt' => 'Final Glyph on Line Alternates',
    'fin2' => 'Terminal Forms #2',
    'fin3' => 'Terminal Forms #3',
    'fina' => 'Terminal Forms',
    'flac' => 'Flattened accent forms',
    'frac' => 'Fractions',
    'fwid' => 'Full Widths',
    'half' => 'Half Forms',
    'haln' => 'Halant Forms',
    'halt' => 'Alternate Half Widths',
    'hist' => 'Historical Forms',
    'hkna' => 'Horizontal Kana Alternates',
    'hlig' => 'Historical Ligatures',
    'hngl' => 'Hangul',
    'hojo' => 'Hojo Kanji Forms',
    'hwid' => 'Half Widths',
    'init' => 'Initial Forms',
    'isol' => 'Isolated Forms',
    'ital' => 'Italics',
    'jalt' => 'Justification Alternates',
    'jp78' => 'JIS78 Forms',
    'jp83' => 'JIS83 Forms',
    'jp90' => 'JIS90 Forms',
    'jp04' => 'JIS2004 Forms',
    'kern' => 'Kerning',
    'lfbd' => 'Left Bounds',
    'liga' => 'Standard Ligatures',
    'ljmo' => 'Leading Jamo Forms',
    'lnum' => 'Lining Figures',
    'locl' => 'Localized Forms',
    'ltra' => 'Left-to-right alternates',
    'ltrm' => 'Left-to-right mirrored forms',
    'mark' => 'Mark Positioning',
    'med2' => 'Medial Forms #2',
    'medi' => 'Medial Forms',
    'mgrk' => 'Mathematical Greek',
    'mkmk' => 'Mark to Mark Positioning',
    'mset' => 'Mark Positioning via Substitution',
    'nalt' => 'Alternate Annotation Forms',
    'nlck' => 'NLC Kanji Forms',
    'nukt' => 'Nukta Forms',
    'numr' => 'Numerators',
    'onum' => 'Oldstyle Figures',
    'opbd' => 'Optical Bounds',
    'ordn' => 'Ordinals',
    'ornm' => 'Ornaments',
    'palt' => 'Proportional Alternate Widths',
    'pcap' => 'Petite Capitals',
    'pkna' => 'Proportional Kana',
    'pnum' => 'Proportional Figures',
    'pref' => 'Pre-Base Forms',
    'pres' => 'Pre-base Substitutions',
    'pstf' => 'Post-base Forms',
    'psts' => 'Post-base Substitutions',
    'pwid' => 'Proportional Widths',
    'qwid' => 'Quarter Widths',
    'rand' => 'Randomize',
    'rclt' => 'Required Contextual Alternates',
    'rkrf' => 'Rakar Forms',
    'rlig' => 'Required Ligatures',
    'rphf' => 'Reph Forms',
    'rtbd' => 'Right Bounds',
    'rtla' => 'Right-to-left alternates',
    'rtlm' => 'Right-to-left mirrored forms',
    'ruby' => 'Ruby Notation Forms',
    'rvrn' => 'Required Variation Alternates',
    'salt' => 'Stylistic Alternates',
    'sinf' => 'Scientific Inferiors',
    'size' => 'Optical size',
    'smcp' => 'Small Capitals',
    'smpl' => 'Simplified Forms',
    'ss01' => 'Stylistic Set 1',
    'ss02' => 'Stylistic Set 2',
    'ss03' => 'Stylistic Set 3',
    'ss04' => 'Stylistic Set 4',
    'ss05' => 'Stylistic Set 5',
    'ss06' => 'Stylistic Set 6',
    'ss07' => 'Stylistic Set 7',
    'ss08' => 'Stylistic Set 8',
    'ss09' => 'Stylistic Set 9',
    'ss10' => 'Stylistic Set 10',
    'ss11' => 'Stylistic Set 11',
    'ss12' => 'Stylistic Set 12',
    'ss13' => 'Stylistic Set 13',
    'ss14' => 'Stylistic Set 14',
    'ss15' => 'Stylistic Set 15',
    'ss16' => 'Stylistic Set 16',
    'ss17' => 'Stylistic Set 17',
    'ss18' => 'Stylistic Set 18',
    'ss19' => 'Stylistic Set 19',
    'ss20' => 'Stylistic Set 20',
    'ssty' => 'Math script style alternates',
    'stch' => 'Stretching Glyph Decomposition',
    'subs' => 'Subscript',
    'sups' => 'Superscript',
    'swsh' => 'Swash',
    'titl' => 'Titling',
    'tjmo' => 'Trailing Jamo Forms',
    'tnam' => 'Traditional Name Forms',
    'tnum' => 'Tabular Figures',
    'trad' => 'Traditional Forms',
    'twid' => 'Third Widths',
    'unic' => 'Unicase',
    'valt' => 'Alternate Vertical Metrics',
    'vatu' => 'Vattu Variants',
    'vert' => 'Vertical Writing',
    'vhal' => 'Alternate Vertical Half Metrics',
    'vjmo' => 'Vowel Jamo Forms',
    'vkna' => 'Vertical Kana Alternates',
    'vkrn' => 'Vertical Kerning',
    'vpal' => 'Proportional Alternate Vertical Metrics',
    'vrt2' => 'Vertical Alternates and Rotation',
    'vrtr' => 'Vertical Alternates for Rotation',
    'zero' => 'Slashed Zero',
  }.freeze

  # The name for one feature tag, or nil when it is not a registered tag —
  # upstream's loop only matches known tags and skips the rest.
  def self.name_for(tag) = FEATURES[tag.to_s]

  # The names for a list of tags, in the table's own order: upstream walks the
  # whole table for each tag the face reports, so the output follows the table
  # rather than the font, and a tag listed in both GSUB and GPOS appears once.
  def self.names_for(tags)
    tags.map(&:to_s).then do |wanted|
      FEATURES.filter_map do |tag, name|
        if wanted.include?(tag)
          name
        end
      end
    end
  end

  # The joined description the info page shows, or nil when the font reports no
  # registered feature — upstream returns NULL then, and omits the row.
  def self.describe(tags)
    names_for(tags).then do |names|
      if names.empty?
        nil
      else
        names.join(SEPARATOR)
      end
    end
  end
end

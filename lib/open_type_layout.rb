# frozen_string_literal: true

require_relative 'translation'

# OpenTypeLayout is the table of registered OpenType layout feature tags and
# their human-readable names.
#
# Ported from upstream's src/open-type-layout.h, which keeps the same table as
# a C array of (tag, name) pairs built with MAKE_TAG. Upstream marks every name
# for translation in the "OpenType layout" message context, and the separator
# the info page joins them with too; both live here.
#
module OpenTypeLayout
  include Translation

  # The separator between feature names. Upstream translates it as
  # C_("OpenType layout", ", ").
  SEPARATOR = p_('OpenType layout', ', ')

  # Tag (the four characters as they appear in a GSUB/GPOS feature list) to
  # name, in upstream's order.
  FEATURES = {
    'aalt' => p_('OpenType layout', 'Access All Alternates'),
    'abvf' => p_('OpenType layout', 'Above-base Forms'),
    'abvm' => p_('OpenType layout', 'Above-base Mark Positioning'),
    'abvs' => p_('OpenType layout', 'Above-base Substitutions'),
    'afrc' => p_('OpenType layout', 'Alternative Fractions'),
    'akhn' => p_('OpenType layout', 'Akhands'),
    'blwf' => p_('OpenType layout', 'Below-base Forms'),
    'blwm' => p_('OpenType layout', 'Below-base Mark Positioning'),
    'blws' => p_('OpenType layout', 'Below-base Substitutions'),
    'calt' => p_('OpenType layout', 'Contextual Alternates'),
    'case' => p_('OpenType layout', 'Case-Sensitive Forms'),
    'ccmp' => p_('OpenType layout', 'Glyph Composition / Decomposition'),
    'cfar' => p_('OpenType layout', 'Conjunct Form After Ro'),
    'cjct' => p_('OpenType layout', 'Conjunct Forms'),
    'clig' => p_('OpenType layout', 'Contextual Ligatures'),
    'cpct' => p_('OpenType layout', 'Centered CJK Punctuation'),
    'cpsp' => p_('OpenType layout', 'Capital Spacing'),
    'cswh' => p_('OpenType layout', 'Contextual Swash'),
    'curs' => p_('OpenType layout', 'Cursive Positioning'),
    'c2pc' => p_('OpenType layout', 'Petite Capitals From Capitals'),
    'c2sc' => p_('OpenType layout', 'Small Capitals From Capitals'),
    'cv01' => p_('OpenType layout', 'Character Variation 1'),
    'cv02' => p_('OpenType layout', 'Character Variation 2'),
    'cv03' => p_('OpenType layout', 'Character Variation 3'),
    'cv04' => p_('OpenType layout', 'Character Variation 4'),
    'cv05' => p_('OpenType layout', 'Character Variation 5'),
    'cv06' => p_('OpenType layout', 'Character Variation 6'),
    'cv07' => p_('OpenType layout', 'Character Variation 7'),
    'cv08' => p_('OpenType layout', 'Character Variation 8'),
    'cv09' => p_('OpenType layout', 'Character Variation 9'),
    'cv10' => p_('OpenType layout', 'Character Variation 10'),
    'cv11' => p_('OpenType layout', 'Character Variation 11'),
    'cv12' => p_('OpenType layout', 'Character Variation 12'),
    'cv13' => p_('OpenType layout', 'Character Variation 13'),
    'cv14' => p_('OpenType layout', 'Character Variation 14'),
    'cv15' => p_('OpenType layout', 'Character Variation 15'),
    'cv16' => p_('OpenType layout', 'Character Variation 16'),
    'cv17' => p_('OpenType layout', 'Character Variation 17'),
    'cv18' => p_('OpenType layout', 'Character Variation 18'),
    'cv19' => p_('OpenType layout', 'Character Variation 19'),
    'dist' => p_('OpenType layout', 'Distances'),
    'dlig' => p_('OpenType layout', 'Discretionary Ligatures'),
    'dnom' => p_('OpenType layout', 'Denominators'),
    'dtls' => p_('OpenType layout', 'Dotless Forms'),
    'expt' => p_('OpenType layout', 'Expert Forms'),
    'falt' => p_('OpenType layout', 'Final Glyph on Line Alternates'),
    'fin2' => p_('OpenType layout', 'Terminal Forms #2'),
    'fin3' => p_('OpenType layout', 'Terminal Forms #3'),
    'fina' => p_('OpenType layout', 'Terminal Forms'),
    'flac' => p_('OpenType layout', 'Flattened accent forms'),
    'frac' => p_('OpenType layout', 'Fractions'),
    'fwid' => p_('OpenType layout', 'Full Widths'),
    'half' => p_('OpenType layout', 'Half Forms'),
    'haln' => p_('OpenType layout', 'Halant Forms'),
    'halt' => p_('OpenType layout', 'Alternate Half Widths'),
    'hist' => p_('OpenType layout', 'Historical Forms'),
    'hkna' => p_('OpenType layout', 'Horizontal Kana Alternates'),
    'hlig' => p_('OpenType layout', 'Historical Ligatures'),
    'hngl' => p_('OpenType layout', 'Hangul'),
    'hojo' => p_('OpenType layout', 'Hojo Kanji Forms'),
    'hwid' => p_('OpenType layout', 'Half Widths'),
    'init' => p_('OpenType layout', 'Initial Forms'),
    'isol' => p_('OpenType layout', 'Isolated Forms'),
    'ital' => p_('OpenType layout', 'Italics'),
    'jalt' => p_('OpenType layout', 'Justification Alternates'),
    'jp78' => p_('OpenType layout', 'JIS78 Forms'),
    'jp83' => p_('OpenType layout', 'JIS83 Forms'),
    'jp90' => p_('OpenType layout', 'JIS90 Forms'),
    'jp04' => p_('OpenType layout', 'JIS2004 Forms'),
    'kern' => p_('OpenType layout', 'Kerning'),
    'lfbd' => p_('OpenType layout', 'Left Bounds'),
    'liga' => p_('OpenType layout', 'Standard Ligatures'),
    'ljmo' => p_('OpenType layout', 'Leading Jamo Forms'),
    'lnum' => p_('OpenType layout', 'Lining Figures'),
    'locl' => p_('OpenType layout', 'Localized Forms'),
    'ltra' => p_('OpenType layout', 'Left-to-right alternates'),
    'ltrm' => p_('OpenType layout', 'Left-to-right mirrored forms'),
    'mark' => p_('OpenType layout', 'Mark Positioning'),
    'med2' => p_('OpenType layout', 'Medial Forms #2'),
    'medi' => p_('OpenType layout', 'Medial Forms'),
    'mgrk' => p_('OpenType layout', 'Mathematical Greek'),
    'mkmk' => p_('OpenType layout', 'Mark to Mark Positioning'),
    'mset' => p_('OpenType layout', 'Mark Positioning via Substitution'),
    'nalt' => p_('OpenType layout', 'Alternate Annotation Forms'),
    'nlck' => p_('OpenType layout', 'NLC Kanji Forms'),
    'nukt' => p_('OpenType layout', 'Nukta Forms'),
    'numr' => p_('OpenType layout', 'Numerators'),
    'onum' => p_('OpenType layout', 'Oldstyle Figures'),
    'opbd' => p_('OpenType layout', 'Optical Bounds'),
    'ordn' => p_('OpenType layout', 'Ordinals'),
    'ornm' => p_('OpenType layout', 'Ornaments'),
    'palt' => p_('OpenType layout', 'Proportional Alternate Widths'),
    'pcap' => p_('OpenType layout', 'Petite Capitals'),
    'pkna' => p_('OpenType layout', 'Proportional Kana'),
    'pnum' => p_('OpenType layout', 'Proportional Figures'),
    'pref' => p_('OpenType layout', 'Pre-Base Forms'),
    'pres' => p_('OpenType layout', 'Pre-base Substitutions'),
    'pstf' => p_('OpenType layout', 'Post-base Forms'),
    'psts' => p_('OpenType layout', 'Post-base Substitutions'),
    'pwid' => p_('OpenType layout', 'Proportional Widths'),
    'qwid' => p_('OpenType layout', 'Quarter Widths'),
    'rand' => p_('OpenType layout', 'Randomize'),
    'rclt' => p_('OpenType layout', 'Required Contextual Alternates'),
    'rkrf' => p_('OpenType layout', 'Rakar Forms'),
    'rlig' => p_('OpenType layout', 'Required Ligatures'),
    'rphf' => p_('OpenType layout', 'Reph Forms'),
    'rtbd' => p_('OpenType layout', 'Right Bounds'),
    'rtla' => p_('OpenType layout', 'Right-to-left alternates'),
    'rtlm' => p_('OpenType layout', 'Right-to-left mirrored forms'),
    'ruby' => p_('OpenType layout', 'Ruby Notation Forms'),
    'rvrn' => p_('OpenType layout', 'Required Variation Alternates'),
    'salt' => p_('OpenType layout', 'Stylistic Alternates'),
    'sinf' => p_('OpenType layout', 'Scientific Inferiors'),
    'size' => p_('OpenType layout', 'Optical size'),
    'smcp' => p_('OpenType layout', 'Small Capitals'),
    'smpl' => p_('OpenType layout', 'Simplified Forms'),
    'ss01' => p_('OpenType layout', 'Stylistic Set 1'),
    'ss02' => p_('OpenType layout', 'Stylistic Set 2'),
    'ss03' => p_('OpenType layout', 'Stylistic Set 3'),
    'ss04' => p_('OpenType layout', 'Stylistic Set 4'),
    'ss05' => p_('OpenType layout', 'Stylistic Set 5'),
    'ss06' => p_('OpenType layout', 'Stylistic Set 6'),
    'ss07' => p_('OpenType layout', 'Stylistic Set 7'),
    'ss08' => p_('OpenType layout', 'Stylistic Set 8'),
    'ss09' => p_('OpenType layout', 'Stylistic Set 9'),
    'ss10' => p_('OpenType layout', 'Stylistic Set 10'),
    'ss11' => p_('OpenType layout', 'Stylistic Set 11'),
    'ss12' => p_('OpenType layout', 'Stylistic Set 12'),
    'ss13' => p_('OpenType layout', 'Stylistic Set 13'),
    'ss14' => p_('OpenType layout', 'Stylistic Set 14'),
    'ss15' => p_('OpenType layout', 'Stylistic Set 15'),
    'ss16' => p_('OpenType layout', 'Stylistic Set 16'),
    'ss17' => p_('OpenType layout', 'Stylistic Set 17'),
    'ss18' => p_('OpenType layout', 'Stylistic Set 18'),
    'ss19' => p_('OpenType layout', 'Stylistic Set 19'),
    'ss20' => p_('OpenType layout', 'Stylistic Set 20'),
    'ssty' => p_('OpenType layout', 'Math script style alternates'),
    'stch' => p_('OpenType layout', 'Stretching Glyph Decomposition'),
    'subs' => p_('OpenType layout', 'Subscript'),
    'sups' => p_('OpenType layout', 'Superscript'),
    'swsh' => p_('OpenType layout', 'Swash'),
    'titl' => p_('OpenType layout', 'Titling'),
    'tjmo' => p_('OpenType layout', 'Trailing Jamo Forms'),
    'tnam' => p_('OpenType layout', 'Traditional Name Forms'),
    'tnum' => p_('OpenType layout', 'Tabular Figures'),
    'trad' => p_('OpenType layout', 'Traditional Forms'),
    'twid' => p_('OpenType layout', 'Third Widths'),
    'unic' => p_('OpenType layout', 'Unicase'),
    'valt' => p_('OpenType layout', 'Alternate Vertical Metrics'),
    'vatu' => p_('OpenType layout', 'Vattu Variants'),
    'vert' => p_('OpenType layout', 'Vertical Writing'),
    'vhal' => p_('OpenType layout', 'Alternate Vertical Half Metrics'),
    'vjmo' => p_('OpenType layout', 'Vowel Jamo Forms'),
    'vkna' => p_('OpenType layout', 'Vertical Kana Alternates'),
    'vkrn' => p_('OpenType layout', 'Vertical Kerning'),
    'vpal' => p_('OpenType layout', 'Proportional Alternate Vertical Metrics'),
    'vrt2' => p_('OpenType layout', 'Vertical Alternates and Rotation'),
    'vrtr' => p_('OpenType layout', 'Vertical Alternates for Rotation'),
    'zero' => p_('OpenType layout', 'Slashed Zero'),
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

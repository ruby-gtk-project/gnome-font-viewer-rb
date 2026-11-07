# frozen_string_literal: true

require 'spec_helper'

# FontThumbnailer requires 'adwaita', which needs a display to initialise
# (see lib/gnome/font/viewer/rb.rb's header comment) — spec_helper.rb
# deliberately stops short of it, so this spec requires it directly and must
# run under a display (`xvfb-run`), same as the drive script.
require 'font_thumbnailer'

# Specs for FontThumbnailer's fallback text selection, ported from
# build_fallback_thumbstr/check_for_ascii_glyph_numbers in
# src/font-thumbnailer.c. These are private, reached with `send` the way
# #thumbnail itself calls them.
RSpec.describe FontThumbnailer do
  subject(:thumbnailer) { described_class.new }

  # `glyphs` maps character -> glyph index, the way the fixtures read; Face
  # itself keys its coverage by codepoint (FontLoader's @glyphs), so this
  # converts.
  def face(glyphs)
    FontLoader::Face.new(
      path:                 nil,
      face_index:           0,
      family_name:          'Example',
      style_name:           'Regular',
      num_glyphs:           glyphs.size,
      sfnt:                 true,
      scalable:             true,
      color:                false,
      sfnt_names:           {},
      variation_axes:       [],
      named_instance_names: [],
      layout_feature_tags:  [],
      fixed_sizes:          [],
      glyphs:               glyphs.to_h { |char, index| [char.ord, index] },
      ps_version:           nil,
      ps_notice:            nil,
    )
  end

  describe '#text_for' do
    it 'uses the requested text when one was given, regardless of coverage' do
      instance = face('A' => 1)
      expect(thumbnailer.send(:text_for, instance, 'Zz')).to eq('Zz')
    end

    it 'defaults to "Aa" when the face can spell it' do
      instance = face('A' => 1, 'a' => 2)
      expect(thumbnailer.send(:text_for, instance, nil)).to eq('Aa')
    end
  end

  describe '#default_text / #fallback_text' do
    it 'falls back to the conventional glyph-index characters when "Aa" is missing' do
      # Glyph indices 65 and 97 are the ones check_for_ascii_glyph_numbers looks
      # for, on a face that cannot spell the literal characters 'A'/'a'.
      instance = face('Q' => 65, 'z' => 97)
      expect(thumbnailer.send(:default_text, instance)).to eq('Qz')
    end

    it 'halves the coverage when neither "Aa" nor the conventional glyphs exist' do
      glyphs = ('a'..'j').each_with_index.to_h { |char, index| [char, index + 1] }
      instance = face(glyphs)
      # 10 covered characters ("abcdefghij"): halved once to index 5 ('f'),
      # then to index 2 ('c').
      expect(thumbnailer.send(:default_text, instance)).to eq('fc')
    end

    it 'falls back to the literal "Aa" when the face covers nothing at all' do
      expect(thumbnailer.send(:default_text, face({}))).to eq('Aa')
    end
  end

  describe '#ascii_characters' do
    it 'returns the characters whose glyph index is 65 or 97, in codepoint order' do
      instance = face('z' => 97, 'Q' => 65)
      expect(thumbnailer.send(:ascii_characters, instance)).to eq('Qz')
    end

    it 'returns an empty string when neither glyph index is present' do
      instance = face('x' => 1)
      expect(thumbnailer.send(:ascii_characters, instance)).to eq('')
    end
  end
end

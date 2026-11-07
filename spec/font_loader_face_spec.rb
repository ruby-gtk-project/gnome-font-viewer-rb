# frozen_string_literal: true

require 'spec_helper'

# Specs for FontLoader::Face, the non-widget model that answers every
# FreeType/HarfBuzz question the info page and preview widget ask about a
# loaded font. Ported logic under test: sushi_get_font_name (font_name),
# check_font_contain_text (contains_text?), describe_axis, describe_instance
# (via describe_named_styles) and OpenTypeLayout's integration (layout_features).
RSpec.describe FontLoader::Face do
  def face(**overrides)
    described_class.new(
      {
        path:                 '/usr/share/fonts/example/Example.ttf',
        face_index:           0,
        family_name:          'Example',
        style_name:           'Regular',
        num_glyphs:           3,
        sfnt:                 true,
        scalable:             true,
        color:                false,
        sfnt_names:           {},
        variation_axes:       [],
        named_instance_names: [],
        layout_feature_tags:  [],
        fixed_sizes:          [],
        glyphs:               { 65 => 1, 97 => 2, 46 => 3 },
        ps_version:           nil,
        ps_notice:            nil,
      }.merge(overrides),
    )
  end

  describe '#font_name' do
    it 'joins family and style with a comma' do
      expect(face(family_name: 'Example', style_name: 'Bold').font_name).to eq('Example, Bold')
    end

    it 'drops the style when it is Regular and the short form is requested' do
      instance = face(family_name: 'Example', style_name: 'Regular')
      expect(instance.font_name(short_form: true)).to eq('Example')
    end

    it 'keeps "Regular" in the long form' do
      instance = face(family_name: 'Example', style_name: 'Regular')
      expect(instance.font_name).to eq('Example, Regular')
    end

    it 'falls back to the family alone when there is no style name' do
      expect(face(family_name: 'Example', style_name: '').font_name).to eq('Example')
    end

    it 'falls back to the file basename when there is no family name' do
      instance = face(family_name: '', style_name: 'Regular', path: '/fonts/Weird.ttf')
      expect(instance.font_name).to eq('Weird.ttf')
    end

    it 'falls back to an empty string with neither a family name nor a path' do
      expect(face(family_name: '', style_name: '', path: nil).font_name).to eq('')
    end
  end

  describe '#contains_text?' do
    it 'is true when every character has a glyph' do
      expect(face.contains_text?('Aa.')).to be(true)
    end

    it 'is false when any character has no glyph' do
      expect(face.contains_text?('Az')).to be(false)
    end
  end

  describe '#characters_for_glyphs' do
    it 'returns the characters whose glyph index matches, in codepoint order' do
      expect(face.characters_for_glyphs([1, 2])).to eq(%w[A a])
    end

    it 'returns nothing when no glyph index matches' do
      expect(face.characters_for_glyphs([999])).to eq([])
    end
  end

  describe '#charlist' do
    it 'is every covered codepoint, sorted, packed as UTF-8' do
      expect(face.charlist).to eq('.Aa')
    end
  end

  describe '#codepoints' do
    it 'is the covered codepoints as an array' do
      expect(face.codepoints).to contain_exactly(65, 97, 46)
    end
  end

  describe '#glyph_for' do
    it 'returns the glyph index for a covered codepoint' do
      expect(face.glyph_for(65)).to eq(1)
    end

    it 'returns nil for an uncovered codepoint' do
      expect(face.glyph_for(90)).to be_nil
    end
  end

  describe '#describe_axis' do
    it 'formats name, range and default with upstream\'s thin-space em dash' do
      axis = Struct.new(:name, :minimum, :maximum, :default).new('Weight', 100.0, 900.0, 400.0)
      expect(face.describe_axis(axis)).to eq("Weight 100 — 900, default 400")
    end
  end

  describe '#describe_named_styles' do
    it 'joins the named instance names with a comma and space' do
      instance = face(named_instance_names: ['Regular', 'Bold', 'Italic'])
      expect(instance.describe_named_styles).to eq('Regular, Bold, Italic')
    end

    it 'is an empty string when there are no named instances' do
      expect(face(named_instance_names: []).describe_named_styles).to eq('')
    end
  end

  describe '#layout_features' do
    it 'describes known OpenType feature tags through OpenTypeLayout' do
      instance = face(layout_feature_tags: %w[liga kern])
      expect(instance.layout_features).to include('Standard Ligatures')
      expect(instance.layout_features).to include('Kerning')
    end

    it 'is nil when the face reports no registered feature' do
      expect(face(layout_feature_tags: []).layout_features).to be_nil
    end
  end

  describe '#sfnt?, #scalable?, #color?' do
    it 'exposes the three boolean flags passed in' do
      instance = face(sfnt: true, scalable: false, color: true)
      expect(instance.sfnt?).to be(true)
      expect(instance.scalable?).to be(false)
      expect(instance.color?).to be(true)
    end
  end

  describe '#sample_string' do
    it 'picks the first sample the face can spell' do
      expect(face.sample_string('xyz', 'Aa.')).to eq('Aa.')
    end

    it 'falls back to a random string drawn from the coverage' do
      expect(face.sample_string('xyz')).to eq(face.charlist)
    end
  end
end

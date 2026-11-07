# frozen_string_literal: true

require 'spec_helper'

# Specs for OpenTypeLayout, the registered tag -> name table ported from
# src/open-type-layout.h.
RSpec.describe OpenTypeLayout do
  describe '.name_for' do
    it 'returns the registered name for a known tag' do
      expect(described_class.name_for('liga')).to eq('Standard Ligatures')
    end

    it 'accepts a symbol the same as a string' do
      expect(described_class.name_for(:kern)).to eq('Kerning')
    end

    it 'returns nil for an unregistered tag' do
      expect(described_class.name_for('zzzz')).to be_nil
    end
  end

  describe '.names_for' do
    it 'follows the table\'s own order rather than the input order' do
      expect(described_class.names_for(%w[liga kern])).to eq(['Kerning', 'Standard Ligatures'])
    end

    it 'lists a tag once even when it is repeated' do
      expect(described_class.names_for(%w[kern kern])).to eq(['Kerning'])
    end

    it 'skips unregistered tags silently' do
      expect(described_class.names_for(%w[kern zzzz])).to eq(['Kerning'])
    end

    it 'is empty for an empty input' do
      expect(described_class.names_for([])).to eq([])
    end
  end

  describe '.describe' do
    it 'joins the names with the upstream separator' do
      expect(described_class.describe(%w[liga kern])).to eq('Kerning, Standard Ligatures')
    end

    it 'is nil when no tag is registered, so the info page omits the row' do
      expect(described_class.describe(%w[zzzz])).to be_nil
    end

    it 'is nil for an empty tag list' do
      expect(described_class.describe([])).to be_nil
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

# InfoPage requires 'adwaita', which needs a display to initialise (see
# lib/gnome/font/viewer/rb.rb's header comment) — spec_helper.rb deliberately
# stops short of it, so this spec requires it directly and must run under a
# display (`xvfb-run`), same as the drive script.
require 'info_page'

# Specs for InfoPage's text-shaping helpers, ported from strip_whitespace,
# strip_version and g_strcompress in src/font-view-window.c. These are
# private, so the specs reach them with `send`, the way the page itself does
# when it populates a row's subtitle.
RSpec.describe InfoPage do
  subject(:page) { described_class.new }

  describe '#strip_whitespace' do
    it 'drops each line\'s leading whitespace' do
      original = "  Copyright 2024\n\tAll rights reserved"
      expect(page.send(:strip_whitespace, original)).to eq("Copyright 2024\nAll rights reserved")
    end

    it 'collapses a run of now-blank trailing lines into one' do
      original = "Line one\n   \n\t\n"
      expect(page.send(:strip_whitespace, original)).to eq("Line one\n")
    end

    it 'keeps an interior blank line that is followed by more text' do
      original = "Line one\n\nLine two"
      expect(page.send(:strip_whitespace, original)).to eq("Line one\n\nLine two")
    end

    it 'returns an unchanged string with no leading whitespace' do
      expect(page.send(:strip_whitespace, 'plain')).to eq('plain')
    end
  end

  describe '#strip_version' do
    it 'keeps only what follows the word "Version"' do
      expect(page.send(:strip_version, 'Version 1.002')).to eq('1.002')
    end

    it 'strips the whitespace between "Version" and the number' do
      expect(page.send(:strip_version, "Version\t2.0")).to eq('2.0')
    end

    it 'returns the original string unchanged when "Version" never appears' do
      expect(page.send(:strip_version, '1.002')).to eq('1.002')
    end
  end

  describe '#compress' do
    it 'unescapes the C escapes a PostScript dictionary writes' do
      expect(page.send(:compress, 'line one\\nline two')).to eq("line one\nline two")
    end

    it 'unescapes tabs, quotes and backslashes' do
      expect(page.send(:compress, 'a\\tb\\\'c\\"d\\\\e')).to eq("a\tb'c\"d\\e")
    end

    it 'returns nil unchanged' do
      expect(page.send(:compress, nil)).to be_nil
    end

    it 'leaves a string with no escapes unchanged' do
      expect(page.send(:compress, 'plain text')).to eq('plain text')
    end
  end
end

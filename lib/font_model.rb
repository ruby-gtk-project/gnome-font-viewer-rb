# frozen_string_literal: true

require 'adwaita'

require_relative 'font_model_item'

# FontModel is the list of installed fonts behind the overview grid.
#
# Ported from upstream's FontViewModel in src/font-model.c and src/font-model.h:
# it asks fontconfig for every scalable font, builds one item per face off the
# main thread, splices them into a GListStore, and rebuilds the whole list when
# fontconfig's timestamp changes.
#
# Upstream talks to libfontconfig directly (FcFontList over an FcObjectSet of
# FC_FILE, FC_INDEX, FC_FAMILY, FC_WEIGHT and FC_SLANT, with FC_SCALABLE true).
# The Ruby bindings have no fontconfig, so the same query goes through fc-list,
# which reads the same database. Note that upstream's object set does not
# include FC_STYLE even though load_font_infos asks each pattern for it: the
# query always comes back empty, so every name is built from the weight and
# slant rather than from the font's own style string. The query here asks for
# exactly what the object set asks for, so the names match.
#
class FontModel
  # The fontconfig query: every scalable font, with the five fields upstream's
  # object set names, tab separated so a family containing a comma survives.
  QUERY_FORMAT = '%{file}\t%{index}\t%{family[0]}\t%{weight}\t%{slant}\n'
  QUERY_PATTERN = ':scalable=true'

  # weight_to_name(): the fontconfig weight constants upstream switches on.
  WEIGHT_NAMES = {
    0   => 'Thin',
    40  => 'Extralight',
    50  => 'Light',
    55  => 'Semilight',
    75  => 'Book',
    80  => 'Regular',
    100 => 'Medium',
    180 => 'Semibold',
    200 => 'Bold',
    205 => 'Extrabold',
    210 => 'Heavy',
    215 => 'Extrablack',
  }.freeze

  # fc_weight_to_pango_weight().
  PANGO_WEIGHTS = {
    0   => :thin,
    40  => :ultralight,
    50  => :light,
    55  => :semilight,
    75  => :book,
    80  => :normal,
    100 => :medium,
    180 => :semibold,
    200 => :bold,
    205 => :ultrabold,
    210 => :heavy,
    215 => :ultraheavy,
  }.freeze

  # slant_to_name(): FC_SLANT_ROMAN has no name, which is why a roman face shows
  # only its weight.
  SLANT_NAMES = {
    0   => nil,
    100 => 'Italic',
    110 => 'Oblique',
  }.freeze

  # fc_slant_to_pango_style().
  PANGO_STYLES = {
    0   => :normal,
    100 => :italic,
    110 => :oblique,
  }.freeze

  # How often the main loop looks in on the worker thread, in milliseconds.
  POLL_INTERVAL = 10

  # The style name upstream's short form drops, so "Family, Regular" shows as
  # just "Family".
  REGULAR = 'Regular'

  attr_reader :list_model

  # on_changed fires after every splice, standing in for the items-changed
  # handler upstream connects to refresh the install button.
  def initialize(&on_changed)
    @on_changed = on_changed
    @list_model = Gio::ListStore.new(FontModelItem)
    @generation = 0
  end

  # font_view_model_init(): schedule the first load, then follow fontconfig.
  def build
    tap do
      schedule_update_font_list
      connect_to_fontconfig_updates
    end
  end

  # ensure_font_list(): drop the current list, re-read the font database on a
  # worker thread, and splice the new items in when it comes back. A load still
  # in flight is abandoned by bumping the generation, which is what upstream's
  # GCancellable does for its task.
  def ensure_font_list
    @generation += 1
    @list_model.remove_all
    load_font_infos(@generation)
  end

  # The items currently in the model.
  def items = @list_model.n_items.times.map { |index| @list_model.get_item(index) }

  # font_view_model_has_face(): whether a loaded face is already installed,
  # matched on the short form of its name the way upstream matches it.
  def has_face?(face)
    face.font_name(short_form: true).then do |name|
      items.any? { |item| item.font_name == name }
    end
  end

  private

    def schedule_update_font_list
      GLib::Idle.add do
        ensure_font_list
        GLib::Source::REMOVE
      end
    end

    # connect_to_fontconfig_updates(): GTK bumps this setting when the font
    # database changes, and upstream rebuilds the list from it.
    def connect_to_fontconfig_updates
      Gtk::Settings.default.signal_connect('notify::gtk-fontconfig-timestamp') do
        ensure_font_list
      end
    end

    # load_font_infos(): the per-font work upstream does in its GTask thread.
    # Only the query happens off the main thread here; the items themselves are
    # GObjects, so they are built back on the main loop before the splice. The
    # loop polls the worker, because a Ruby thread only runs when the loop wakes.
    def load_font_infos(generation)
      Thread.new { query_fontconfig }.then do |worker|
        await(worker, generation)
      end
    end

    def await(worker, generation)
      GLib::Timeout.add(POLL_INTERVAL) do
        if worker.alive?
          true
        else
          splice(worker.value, generation)
          GLib::Source::REMOVE
        end
      end
    end

    def splice(rows, generation)
      if generation == @generation
        rows.map { |row| build_item(row) }.then do |items|
          @list_model.splice(0, 0, items)
          @on_changed&.call
        end
      end
    end

    def query_fontconfig
      `fc-list --format '#{QUERY_FORMAT}' #{QUERY_PATTERN}`.lines.filter_map do |line|
        parse_row(line)
      end
    rescue SystemCallError
      []
    end

    def parse_row(line)
      line.chomp.split("\t", -1).then do |fields|
        if fields.length < 5 || fields[0].empty?
          nil
        else
          {
            path:       fields[0],
            face_index: fields[1].to_i,
            family:     nil_if_empty(fields[2]),
            weight:     integer_or_missing(fields[3]),
            slant:      integer_or_missing(fields[4]),
          }
        end
      end
    end

    def nil_if_empty(value)
      if value.empty?
        nil
      else
        value
      end
    end

    # Upstream sets weight and slant to -1 when FcPatternGetInteger finds no
    # match, which leaves both names unset.
    def integer_or_missing(value)
      if value.empty?
        -1
      else
        value.to_i
      end
    end

    def build_item(row)
      FontModelItem.new(
        font_name:        font_name(row),
        preview_text:     FontModelItem::PREVIEW_TEXT,
        font_description: font_description(row),
        path:             row[:path],
        face_index:       row[:face_index],
      )
    end

    # build_font_name(): the style name is the font's own when fontconfig gives
    # one, and otherwise the weight and slant names joined; with no family name
    # at all the item is named by the empty string.
    def font_name(row)
      style_name(row).then do |style|
        if row[:family].nil?
          ''
        elsif style.nil? || style == REGULAR
          row[:family]
        else
          "#{row[:family]}, #{style}"
        end
      end
    end

    def style_name(row)
      slant = SLANT_NAMES[row[:slant]]
      weight = WEIGHT_NAMES[row[:weight]]
      [weight, slant].compact.join(' ').then { |style| nil_if_empty(style) }
    end

    def font_description(row)
      Pango::FontDescription.new.tap do |description|
        description.family = row[:family].to_s
        description.weight = PANGO_WEIGHTS.fetch(row[:weight], :normal)
        description.style = PANGO_STYLES.fetch(row[:slant], :normal)
      end
    end
end

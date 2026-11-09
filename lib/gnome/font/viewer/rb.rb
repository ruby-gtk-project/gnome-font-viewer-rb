# frozen_string_literal: true

# The part of the font viewer that loads without a display.
#
# This file exists because `require 'adwaita'` initialises GTK at require time
# and raises Gtk::InitError when there is no display server, so anything that
# reaches a widget class cannot be loaded by a plain `ruby -e` or by a test
# process on a headless machine. The split is along that line and no other:
#
#   require 'gnome/font/viewer/rb'   the OpenType layout table, the gettext
#                                   bootstrap, the resource monitor and the
#                                   font loader — no gtk4, no adwaita,
#                                   loadable anywhere;
#   require 'gnome_font_viewer'      all of the above plus every widget and
#                                   the application, which needs a display.
#
# It is also the file the gem's version constant lives under, which is why
# spec/spec_helper.rb requires it: the specs for the display-free half need
# nothing more, and the ones that drive widgets ask for the application
# directly.
require_relative '../../../translation'
require_relative '../../../open_type_layout'
require_relative '../../../resource_monitor'
require_relative '../../../font_loader'
require_relative "rb/version"

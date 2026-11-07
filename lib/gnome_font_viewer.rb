# frozen_string_literal: true

# The display-free half (the font loader, the OpenType layout table, the
# gettext bootstrap, the resource monitor and the version) plus everything
# that needs a display: every widget and the application itself.
require_relative "gnome/font/viewer/rb"
require_relative "font_view_application"
require_relative "font_thumbnailer"

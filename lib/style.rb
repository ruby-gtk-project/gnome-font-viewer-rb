# frozen_string_literal: true

require 'adwaita'

# Style is the application's stylesheet: the padding around the grid, the padding
# inside each cell, and the size the cell previews are drawn at.
#
# Ported from src/style.css, which upstream ships in the GResource bundle
# declared by src/gnome-font-viewer.gresource.xml and GTK picks up from the
# application's resource base path. There is no GResource here, so the same CSS
# is loaded from a GtkCssProvider onto the default display.
#
module Style
  # src/style.css, verbatim.
  CSS = <<~CSS
    gridview {
      padding: 16px;
    }

    .font-item {
      padding: 8px;
    }

    .font-preview {
      font-size: 128px;
    }
  CSS

  # Where the application's own styles sit, above the theme and below the user's.
  PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION

  def self.apply
    provider.tap do |css|
      Gtk::StyleContext.add_provider_for_display(Gdk::Display.default, css, PRIORITY)
    end
  end

  def self.provider
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load(data: CSS)
    end
  end
end

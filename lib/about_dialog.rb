# frozen_string_literal: true

require 'adwaita'

require_relative 'gnome/font/viewer/rb/version'
require_relative 'translation'

# AboutDialog is what the About button in the overview header bar opens.
#
# Ported from action_about in src/font-view-application.c, which calls
# adw_show_about_dialog with the developer list, the application name and icon,
# the project's website and issue tracker, the translator credits and the
# licence.
#
class AboutDialog
  include Translation

  APPLICATION_NAME = _('Fonts')

  # adw_show_about_dialog's developer-name, which upstream marks translatable.
  DEVELOPER_NAME = _('The GNOME Project')
  WEBSITE = 'https://gitlab.gnome.org/GNOME/gnome-font-viewer/'
  ISSUE_URL = 'https://gitlab.gnome.org/GNOME/gnome-font-viewer/-/issues/'

  # Upstream's developers array, in its order.
  DEVELOPERS = [
    'Christopher Davis',
    'Evan Welsh',
    'Cosimo Cecchi',
    'James Henstridge',
  ].freeze

  # The msgid upstream passes through gettext so each translation team can sign
  # its own work.
  TRANSLATOR_CREDITS = _('translator-credits')

  def initialize(icon_name)
    @icon_name = icon_name
  end

  # adw_show_about_dialog(): build it, then present it over the window.
  def show(parent)
    dialog.present(parent)
  end

  def dialog
    @dialog ||= Adwaita::AboutDialog.new.tap do |about|
      about.application_name = APPLICATION_NAME
      about.application_icon = @icon_name
      about.developer_name = DEVELOPER_NAME
      about.version = Gnome::Font::Viewer::Rb::VERSION
      about.developers = DEVELOPERS
      about.website = WEBSITE
      about.issue_url = ISSUE_URL
      about.translator_credits = TRANSLATOR_CREDITS
      about.license_type = :gpl_2_0
    end
  end
end

# frozen_string_literal: true

require 'gettext'

# Translation is the gettext bootstrap every other file in lib/ includes to
# reach `_()`/`p_()`. It has no upstream counterpart: upstream's translation
# surface is GLib's bindtextdomain/gettext wired up by main.c's
# `setlocale`/`bindtextdomain`/`textdomain` calls and consumed through plain
# `_()` and `C_()` macros everywhere else. This module is the Ruby equivalent
# of that one-time setup, built on the `gettext` gem rather than GNU libintl.
#
# Including this module binds the including class to the application's text
# domain and gives it `_`, `n_`, `p_`, `s_` and friends (see GetText) as both
# instance and class/module methods, which is what every file that defines a
# user-facing string constant at class-body load time needs: the include has
# to run before the constant assignments below it so `_('Fonts')` resolves
# against the domain rather than raising GetText::NoboundTextDomainError.
module Translation
  # po/POTFILES.in's domain and the name msgfmt compiles po/*.po under:
  # locale/<lang>/LC_MESSAGES/#{TEXT_DOMAIN}.mo.
  TEXT_DOMAIN = 'gnome-font-viewer-rb'

  # Where the compiled catalogues live, mirroring GLib's own search path
  # (`<prefix>/share/locale`) but rooted at this checkout/gem so the app finds
  # its own translations without a system install. `rake mo` writes here, and
  # it is Ruby's answer to upstream's GResource-free locale directory: there is
  # no bundle to carry translations here, so they are plain files on disk.
  LOCALE_DIR = File.expand_path('../locale', __dir__)

  def self.included(base)
    base.include(GetText)
    base.bindtextdomain(TEXT_DOMAIN, path: LOCALE_DIR)
  end
end

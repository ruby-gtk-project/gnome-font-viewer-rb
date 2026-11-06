# frozen_string_literal: true

require 'adwaita'

require_relative 'translation'

# ErrorDialog is the alert the window raises when a font will not display or
# will not install.
#
# Ported from the AdwAlertDialog with id "error_dialog" in
# src/font-view-window.ui, and from font_view_window_show_error in
# src/font-view-window.c, which sets the heading and the body and presents the
# dialog over the window. The dialog carries one response, "_Close".
#
class ErrorDialog
  include Translation

  CLOSE_RESPONSE = 'close'
  CLOSE_LABEL = _('_Close')

  def build
    dialog.tap do |alert|
      alert.add_response(CLOSE_RESPONSE, CLOSE_LABEL)
      alert.close_response = CLOSE_RESPONSE
      alert.default_response = CLOSE_RESPONSE
    end
  end

  # font_view_window_show_error(): heading and body, presented over the window.
  def show(parent, heading, body)
    dialog.tap do |alert|
      alert.heading = heading.to_s
      alert.body = body.to_s
      alert.present(parent)
    end
  end

  def dialog = @dialog ||= Adwaita::AlertDialog.new('', '')
end

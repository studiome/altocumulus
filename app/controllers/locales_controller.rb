# Lets a visitor switch the UI language from the nav, before or after
# signing in. Never trusts params[:locale] directly: only a value already
# present in I18n.available_locales is accepted (see the `t` param
# validation below), which is what keeps arbitrary user input from ever
# reaching `I18n.locale=`.
class LocalesController < ApplicationController
  skip_before_action :require_login

  def update
    requested_locale = params[:locale].to_s

    if I18n.available_locales.map(&:to_s).include?(requested_locale)
      if current_user
        current_user.update(locale: requested_locale)
      else
        session[:locale] = requested_locale
      end
    end

    redirect_back fallback_location: root_path
  end
end

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # enforce_session_idle_timeout must run BEFORE switch_locale: it can
  # reset_session on an expired session, and switch_locale's locale
  # resolution reads current_user, which memoizes @current_user from
  # whatever the session holds at that moment. If switch_locale ran first,
  # it would memoize the about-to-expire user, and require_login (also
  # wrapped by switch_locale, so it runs after) would then see that stale
  # memoized user and skip the redirect even though the session was reset.
  # switch_locale still wraps require_login and set_current_attributes, so
  # its redirect-with-flash and every other response render in the
  # resolved locale, not only a successful one.
  before_action :enforce_session_idle_timeout
  around_action :switch_locale
  before_action :require_login
  before_action :set_current_attributes

  helper_method :current_user, :admin?

  private

  # Locale precedence: a signed-in user's saved preference, then whatever
  # was picked before signing in (or by an anonymous visitor), then the
  # app default. Scoped with I18n.with_locale (not a bare `I18n.locale =`
  # assignment) so the change never leaks into another request handled by
  # the same thread/worker.
  def switch_locale(&action)
    I18n.with_locale(resolve_locale, &action)
  end

  def resolve_locale
    current_user&.locale || session[:locale] || I18n.default_locale
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.active.find_by(id: session[:user_id])
  end

  def admin?
    current_user&.admin? || false
  end

  def require_login
    return if current_user

    redirect_to login_path, alert: "Please sign in to continue."
  end

  def require_admin
    return if admin?

    redirect_to root_path, alert: "You are not authorized to perform this action."
  end

  def set_current_attributes
    Current.user = current_user
    Current.ip_address = request.remote_ip
  end

  def enforce_session_idle_timeout
    return unless session[:user_id]

    last_seen_at = session[:last_seen_at]
    if last_seen_at.present? && Time.zone.at(last_seen_at) < Rails.application.config.x.session_idle_timeout.ago
      expire_idle_session
      return
    end

    session[:last_seen_at] = Time.current.to_i
  end

  def expire_idle_session
    timed_out_user = User.find_by(id: session[:user_id])
    reset_session
    record_access_log(user: timed_out_user, event: "timeout")
  end

  def record_access_log(user:, event:)
    AccessLog.create!(
      user: user,
      event: event,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      last_url: request.original_url
    )
  end
end

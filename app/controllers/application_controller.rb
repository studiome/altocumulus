class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :enforce_session_idle_timeout
  before_action :require_login
  before_action :set_current_attributes

  helper_method :current_user, :admin?

  private

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

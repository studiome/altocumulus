# The one rule for "which user does this session belong to", shared by
# ApplicationController (every request) and ApplicationCable::Connection (the
# live update socket) so the two cannot drift apart.
module SessionUser
  # An active user whose password fingerprint matches the session's: a
  # password change invalidates every session signed in before it.
  def self.find(session)
    user = session[:user_id] && User.active.find_by(id: session[:user_id])
    return nil unless user
    return nil unless ActiveSupport::SecurityUtils.secure_compare(session[:password_fingerprint].to_s, user.session_fingerprint.to_s)

    user
  end

  # True when the session was last seen longer ago than the idle timeout.
  def self.idle?(session)
    last_seen_at = session[:last_seen_at]
    last_seen_at.present? && Time.zone.at(last_seen_at) < Rails.application.config.x.session_idle_timeout.ago
  end
end

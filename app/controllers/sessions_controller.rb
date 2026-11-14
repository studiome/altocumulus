class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[ new create ]
  # Both the form and the re-render after a failed sign-in show the notices.
  before_action :load_announcements, only: %i[ new create ]

  # Per-IP throttle on sign-in attempts. The store is swappable so a test can
  # exercise the limit (the test environment's cache is a null store).
  class << self
    attr_writer :login_rate_limit_store

    def login_rate_limit_store
      @login_rate_limit_store || Rails.cache
    end
  end

  LOGIN_RATE_LIMIT_STORE = Object.new.tap do |store|
    def store.increment(*args, **options)
      SessionsController.login_rate_limit_store.increment(*args, **options)
    end
  end

  rate_limit to: 10, within: 3.minutes, only: :create, store: LOGIN_RATE_LIMIT_STORE, with: :login_rate_limited

  def new
  end

  def create
    # Scoping to `active` before `authenticate_by` means a deactivated user's
    # record is invisible to the lookup, so it falls into the same "not
    # found" branch as an unknown login id: `authenticate_by` still runs a
    # dummy BCrypt hash in that branch, keeping the response time
    # indistinguishable from a truly nonexistent login id (see
    # ActiveRecord::SecurePassword).
    user = User.active.authenticate_by(
      login_id: session_params[:login_id],
      password: session_params[:password]
    )

    if user
      # A fresh session on sign-in (against session fixation); only the
      # pre-login language choice is carried over.
      locale = session[:locale]
      reset_session
      session[:locale] = locale if locale
      session[:user_id] = user.id
      session[:password_fingerprint] = user.session_fingerprint
      session[:last_seen_at] = Time.current.to_i
      record_access_log(user: user, event: "login")
      redirect_to root_path, notice: t(".success_notice")
    else
      # `authenticate_by` returns nil both for "wrong password" and for
      # "no matching (active) user", so we can no longer tell which user a
      # failed attempt was aimed at. That's intentional, not a bug: keeping
      # this log free of user attribution is what avoids leaking, via the
      # log itself or the timing of code that reads it, that a deactivated
      # account exists. IP, user agent and timestamp are still recorded.
      # Please do not "fix" this back to attributing failures to a user.
      record_access_log(user: nil, event: "login_failed")
      flash.now[:alert] = t(".invalid_credentials_alert_#{User.identifier_mode}")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if current_user
      record_access_log(user: current_user, event: "logout")
      ActionCable.server.remote_connections.where(current_user: current_user).disconnect
    end
    reset_session
    redirect_to login_path, notice: t(".success_notice")
  end

  private

  def load_announcements
    @announcements = Announcement.published.recent_first
  end

  def login_rate_limited
    load_announcements
    flash.now[:alert] = t("sessions.create.rate_limited_alert")
    render :new, status: :too_many_requests
  end

  # Only plain strings are credentials; a malformed shape (string, hash or
  # array where a field is expected) is just a failed sign-in, not a 500.
  def session_params
    raw = params[:session]
    return { login_id: "", password: "" } unless raw.is_a?(ActionController::Parameters)

    {
      login_id: raw[:login_id].is_a?(String) ? raw[:login_id] : "",
      password: raw[:password].is_a?(String) ? raw[:password] : ""
    }
  end
end

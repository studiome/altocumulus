class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[ new create ]

  def new
  end

  def create
    # Scoping to `active` before `authenticate_by` means a deactivated user's
    # record is invisible to the lookup, so it falls into the same "not
    # found" branch as an unknown email: `authenticate_by` still runs a dummy
    # BCrypt hash in that branch, keeping the response time indistinguishable
    # from a truly nonexistent email (see ActiveRecord::SecurePassword).
    user = User.active.authenticate_by(
      email: session_params[:email],
      password: session_params[:password]
    )

    if user
      session[:user_id] = user.id
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
      flash.now[:alert] = t(".invalid_credentials_alert")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    record_access_log(user: current_user, event: "logout") if current_user
    reset_session
    redirect_to login_path, notice: t(".success_notice")
  end

  private

  def session_params
    params.fetch(:session, {})
  end
end

class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[ new create ]

  def new
  end

  def create
    user = User.find_by(email: session_params[:email])

    if user&.active? && user.authenticate(session_params[:password])
      session[:user_id] = user.id
      session[:last_seen_at] = Time.current.to_i
      record_access_log(user: user, event: "login")
      redirect_to root_path, notice: "Signed in successfully."
    else
      record_access_log(user: user, event: "login_failed")
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    record_access_log(user: current_user, event: "logout") if current_user
    reset_session
    redirect_to login_path, notice: "Signed out."
  end

  private

  def session_params
    params.fetch(:session, {})
  end
end

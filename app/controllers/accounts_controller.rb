class AccountsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user

    if password_change_requested?
      return render_password_change_error(:password_confirmation, :blank) if new_password_confirmation.blank?
      return render_password_change_error(:current_password, :incorrect) unless @user.authenticate(current_password_param)
    end

    if @user.update(account_params)
      redirect_to account_path, notice: t(".success_notice")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def password_change_requested?
    new_password.present? || new_password_confirmation.present?
  end

  def new_password
    params.dig(:user, :password)
  end

  def new_password_confirmation
    params.dig(:user, :password_confirmation)
  end

  def current_password_param
    params.dig(:user, :current_password).to_s
  end

  def render_password_change_error(attribute, message)
    @user.errors.add(attribute, message)
    render :show, status: :unprocessable_entity
  end

  def account_params
    params.expect(user: [ :name, :email, :password, :password_confirmation ])
  end
end

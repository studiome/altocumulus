module Admin
  class UsersController < ApplicationController
    before_action :require_admin
    before_action :set_user, only: %i[ edit update reset_password ]

    def index
      @users = User.order(:login_id)
    end

    def new
      @user = User.new(role: "user", active: true)
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: t(".success_notice")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @user.update(user_update_params)
        redirect_to admin_users_path, notice: t(".success_notice")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def reset_password
      temporary_password = SecureRandom.alphanumeric(12)

      if @user.update(password: temporary_password, password_confirmation: temporary_password)
        redirect_to admin_users_path, notice: t(".success_notice", password: temporary_password)
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params.expect(:id))
    end

    def user_params
      params.expect(user: [ :name, :login_id, :password, :password_confirmation, :role, :active ])
    end

    def user_update_params
      params.expect(user: [ :name, :login_id, :role, :active ])
    end
  end
end

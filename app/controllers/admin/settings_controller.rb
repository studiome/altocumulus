module Admin
  class SettingsController < ApplicationController
    before_action :require_admin

    def edit
      @app_setting = AppSetting.current
      @app_setting.title = AppSetting.title if @app_setting.title.blank?
    end

    def update
      @app_setting = AppSetting.current

      if @app_setting.update(app_setting_params)
        redirect_to edit_admin_settings_path, notice: t(".success_notice"), status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def app_setting_params
      params.expect(app_setting: [ :title ])
    end
  end
end

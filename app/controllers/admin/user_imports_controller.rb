module Admin
  class UserImportsController < ApplicationController
    before_action :require_admin

    def new
      @user_import = UserImport.new
    end

    def create
      @user_import = UserImport.new(user_import_params)

      if @user_import.valid?
        @result = @user_import.run
        render :create
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def user_import_params
      params.expect(user_import: [ :file ])
    end
  end
end

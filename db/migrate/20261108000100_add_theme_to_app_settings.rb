class AddThemeToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :theme, :string
  end
end

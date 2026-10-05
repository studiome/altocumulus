class DefaultUserLocaleToJapanese < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :locale, from: "en", to: "ja"
    execute "UPDATE users SET locale = 'ja'"
  end

  # Only the column default is restored: which users were on "en" before the
  # bulk switch is not recorded, so their locale is left as it is.
  def down
    change_column_default :users, :locale, from: "ja", to: "en"
  end
end

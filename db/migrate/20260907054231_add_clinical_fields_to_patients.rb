class AddClinicalFieldsToPatients < ActiveRecord::Migration[8.1]
  def change
    add_column :patients, :name_kana, :string
    add_column :patients, :sex, :string
    add_column :patients, :telephone, :string
    add_column :patients, :clinical_info, :text
  end
end

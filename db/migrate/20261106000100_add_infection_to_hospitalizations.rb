class AddInfectionToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :infection, :string
  end
end

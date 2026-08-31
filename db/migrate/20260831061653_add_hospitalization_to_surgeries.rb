class AddHospitalizationToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_reference :surgeries, :hospitalization, null: true, foreign_key: true
  end
end

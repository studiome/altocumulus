class RemoveHospitalizationFromSurgeries < ActiveRecord::Migration[8.1]
  def change
    remove_reference :surgeries, :hospitalization, index: true, foreign_key: true
  end
end

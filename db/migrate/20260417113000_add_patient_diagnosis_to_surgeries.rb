class AddPatientDiagnosisToSurgeries < ActiveRecord::Migration[8.1]
  def change
    add_reference :surgeries, :patient_diagnosis, foreign_key: true
  end
end

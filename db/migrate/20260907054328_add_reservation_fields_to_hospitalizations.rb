class AddReservationFieldsToHospitalizations < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :scheduled_admission_date, :date
    add_column :hospitalizations, :reservation_status, :string, null: false, default: "requested"
    add_column :hospitalizations, :purpose, :string, null: false, default: "surgery"
    add_column :hospitalizations, :ward, :string
    add_column :hospitalizations, :referred_from, :string
    add_column :hospitalizations, :adl, :string
    add_column :hospitalizations, :reservation_doctor, :string
    add_column :hospitalizations, :attending_doctor, :string
    add_column :hospitalizations, :submitted_on, :date
    add_column :hospitalizations, :clinical_comment, :text

    add_index :hospitalizations, :scheduled_admission_date

    # Reservation-stage hospitalizations only have a scheduled_admission_date
    # until the patient actually checks in, so admission_date can no longer
    # be required at the database level.
    change_column_null :hospitalizations, :admission_date, true
  end
end

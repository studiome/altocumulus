# Hospitalization workflow fields: emergency admission, transfer status (with
# the department transferred from), who entered the record, a procedure
# schedule for non-surgery admissions, and the reservation doctor as a user.
#
# The old free-text reservation_doctor column is kept as
# reservation_doctor_legacy_name for historical values that match no user;
# values that do match are moved to reservation_doctor_id (ReservationDoctorBackfill,
# plain SQL). `down` writes the linked users' names back.
class AddWorkflowFieldsToHospitalizations < ActiveRecord::Migration[8.1]
  def up
    add_column :hospitalizations, :emergency_admission, :boolean, null: false, default: false
    add_column :hospitalizations, :transfer_status, :string, null: false, default: "none"
    add_reference :hospitalizations, :source_department, foreign_key: { to_table: :departments }
    add_reference :hospitalizations, :created_by, foreign_key: { to_table: :users }
    add_column :hospitalizations, :scheduled_procedure_date, :date
    add_column :hospitalizations, :procedure_name, :string

    rename_column :hospitalizations, :reservation_doctor, :reservation_doctor_legacy_name
    add_reference :hospitalizations, :reservation_doctor, foreign_key: { to_table: :users }

    result = backfill.up
    say "reservation doctors linked to users: #{result[:matched]}, left as legacy text: #{result[:unmatched]}"
  end

  def down
    backfill.down

    remove_reference :hospitalizations, :reservation_doctor, foreign_key: { to_table: :users }
    rename_column :hospitalizations, :reservation_doctor_legacy_name, :reservation_doctor

    remove_column :hospitalizations, :procedure_name
    remove_column :hospitalizations, :scheduled_procedure_date
    remove_reference :hospitalizations, :created_by, foreign_key: { to_table: :users }
    remove_reference :hospitalizations, :source_department, foreign_key: { to_table: :departments }
    remove_column :hospitalizations, :transfer_status
    remove_column :hospitalizations, :emergency_admission
  end

  private

    def backfill
      ReservationDoctorBackfill.new(connection, table: :hospitalizations, users_table: :users,
                                    string_column: :reservation_doctor_legacy_name, fk_column: :reservation_doctor_id)
    end
end

# surgeries.target_department / surgeries.location (free text) become foreign
# keys to the departments / surgery_locations masters, and surgeries gain an
# optional surgical_device_id. Existing strings are folded into master rows
# (MasterBackfill, plain SQL); `down` writes the names back into the strings.
class ReplaceSurgeryFreeTextWithMasterReferences < ActiveRecord::Migration[8.1]
  def up
    add_reference :surgeries, :department, foreign_key: true
    add_reference :surgeries, :surgery_location, foreign_key: true
    add_reference :surgeries, :surgical_device, foreign_key: true

    backfill(:target_department, :department_id, :departments).up
    backfill(:location, :surgery_location_id, :surgery_locations).up

    remove_column :surgeries, :target_department
    remove_column :surgeries, :location
  end

  def down
    add_column :surgeries, :target_department, :string
    add_column :surgeries, :location, :string

    backfill(:target_department, :department_id, :departments).down
    backfill(:location, :surgery_location_id, :surgery_locations).down

    remove_reference :surgeries, :surgical_device, foreign_key: true
    remove_reference :surgeries, :surgery_location, foreign_key: true
    remove_reference :surgeries, :department, foreign_key: true
  end

  private

    def backfill(string_column, fk_column, master_table)
      MasterBackfill.new(connection, table: :surgeries, string_column: string_column,
                                     fk_column: fk_column, master_table: master_table)
    end
end

# Surgery workflow fields: the hospitalization a surgery belongs to (backfilled
# for existing dated surgeries, see SurgeryHospitalizationBackfill), the
# intervention answer for backup cases, the performing department, plus a hint
# on surgery locations that the performing department is worth asking for.
# `down` just drops the columns.
class AddWorkflowFieldsToSurgeries < ActiveRecord::Migration[8.1]
  def up
    add_reference :surgeries, :hospitalization, foreign_key: true
    add_column :surgeries, :backup_intervention, :string
    add_reference :surgeries, :performing_department, foreign_key: { to_table: :departments }
    add_column :surgery_locations, :asks_performing_department, :boolean, null: false, default: false

    result = SurgeryHospitalizationBackfill.new(connection).up
    say "surgeries linked to a hospitalization: #{result[:linked]}, ambiguous: #{result[:ambiguous]}, no match: #{result[:unmatched]}"
  end

  def down
    remove_column :surgery_locations, :asks_performing_department
    remove_reference :surgeries, :performing_department, foreign_key: { to_table: :departments }
    remove_column :surgeries, :backup_intervention
    remove_reference :surgeries, :hospitalization, foreign_key: true
  end
end

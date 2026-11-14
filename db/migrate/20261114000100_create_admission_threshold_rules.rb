class CreateAdmissionThresholdRules < ActiveRecord::Migration[8.1]
  def change
    create_table :admission_threshold_rules do |t|
      t.integer :day_of_week, null: false
      t.integer :threshold, null: false
      t.timestamps
    end
    add_index :admission_threshold_rules, :day_of_week, unique: true
    add_check_constraint :admission_threshold_rules, "day_of_week BETWEEN 0 AND 6", name: "admission_threshold_rules_day_of_week_range"
    add_check_constraint :admission_threshold_rules, "threshold >= 0", name: "admission_threshold_rules_threshold_non_negative"

    add_column :holidays, :admission_threshold, :integer
    add_check_constraint :holidays, "admission_threshold IS NULL OR admission_threshold >= 0", name: "holidays_admission_threshold_non_negative"
  end
end

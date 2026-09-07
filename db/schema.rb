# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_07_090003) do
  create_table "access_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.string "ip_address"
    t.string "last_url"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id"
    t.index ["created_at"], name: "index_access_logs_on_created_at"
    t.index ["user_id"], name: "index_access_logs_on_user_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "auditable_id", null: false
    t.string "auditable_type", null: false
    t.json "change_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.string "record_label", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["auditable_type", "action"], name: "index_audit_events_on_auditable_type_and_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "diagnoses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_diagnoses_on_name", unique: true
  end

  create_table "elective_slot_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.decimal "slot_count", precision: 4, scale: 1
    t.integer "slot_duration_minutes", null: false
    t.datetime "updated_at", null: false
    t.index ["day_of_week"], name: "index_elective_slot_rules_on_day_of_week", unique: true
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "holiday", default: true, null: false
    t.string "name"
    t.text "note"
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_holidays_on_date", unique: true
  end

  create_table "hospitalization_diagnoses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "diagnosis_id", null: false
    t.integer "hospitalization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_id"], name: "index_hospitalization_diagnoses_on_diagnosis_id"
    t.index ["hospitalization_id", "diagnosis_id"], name: "index_hosp_diagnoses_on_hosp_id_and_diagnosis_id", unique: true
    t.index ["hospitalization_id"], name: "index_hospitalization_diagnoses_on_hospitalization_id"
  end

  create_table "hospitalizations", force: :cascade do |t|
    t.string "adl"
    t.string "admin_status", default: "unconfirmed", null: false
    t.date "admission_date"
    t.string "attending_doctor"
    t.text "clinical_comment"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.date "discharge_date"
    t.string "discharge_destination"
    t.string "outcome"
    t.integer "patient_age_snapshot"
    t.integer "patient_id", null: false
    t.string "patient_name_snapshot"
    t.string "patient_sex_snapshot"
    t.integer "planned_days"
    t.string "purpose", default: "surgery", null: false
    t.text "reason"
    t.string "referred_from"
    t.string "reservation_doctor"
    t.string "reservation_status", default: "requested", null: false
    t.string "room_preference"
    t.date "scheduled_admission_date"
    t.date "submitted_on"
    t.datetime "updated_at", null: false
    t.string "ward"
    t.index ["deleted_at"], name: "index_hospitalizations_on_deleted_at"
    t.index ["discharge_date"], name: "index_hospitalizations_on_discharge_date"
    t.index ["patient_id", "admission_date"], name: "index_hospitalizations_on_patient_id_and_admission_date"
    t.index ["patient_id"], name: "index_hospitalizations_on_patient_id"
    t.index ["scheduled_admission_date"], name: "index_hospitalizations_on_scheduled_admission_date"
  end

  create_table "patient_diagnoses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "diagnosed_on", null: false
    t.integer "diagnosis_id", null: false
    t.string "laterality", default: "none", null: false
    t.integer "patient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["diagnosis_id"], name: "index_patient_diagnoses_on_diagnosis_id"
    t.index ["patient_id", "diagnosed_on"], name: "index_patient_diagnoses_on_patient_id_and_diagnosed_on"
    t.index ["patient_id"], name: "index_patient_diagnoses_on_patient_id"
  end

  create_table "patients", force: :cascade do |t|
    t.text "clinical_info"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "hospital_id"
    t.string "name"
    t.string "name_kana"
    t.string "sex"
    t.string "telephone"
    t.datetime "updated_at", null: false
    t.index ["hospital_id"], name: "index_patients_on_hospital_id", unique: true
  end

  create_table "surgeries", force: :cascade do |t|
    t.string "anesthesia_method"
    t.string "assistant_name"
    t.datetime "created_at", null: false
    t.float "duration_hours"
    t.integer "hospitalization_id"
    t.integer "operation_order"
    t.string "operator_name"
    t.integer "patient_id", null: false
    t.string "scheduling_type", default: "elective", null: false
    t.integer "slot_number"
    t.time "start_time"
    t.date "surgery_date"
    t.datetime "updated_at", null: false
    t.index ["hospitalization_id"], name: "index_surgeries_on_hospitalization_id"
    t.index ["patient_id"], name: "index_surgeries_on_patient_id"
    t.index ["surgery_date", "scheduling_type"], name: "index_surgeries_on_surgery_date_and_scheduling_type"
    t.index ["surgery_date", "slot_number"], name: "index_surgeries_on_surgery_date_and_slot_number"
  end

  create_table "surgery_diagnosis_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "patient_diagnosis_id", null: false
    t.integer "surgery_id", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_diagnosis_id"], name: "index_surgery_diagnosis_links_on_patient_diagnosis_id"
    t.index ["surgery_id", "patient_diagnosis_id"], name: "idx_on_surgery_id_patient_diagnosis_id_434c0ea0bf", unique: true
    t.index ["surgery_id"], name: "index_surgery_diagnosis_links_on_surgery_id"
  end

  create_table "surgery_procedure_selections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "laterality", default: "none", null: false
    t.integer "surgery_id", null: false
    t.integer "surgery_procedure_id", null: false
    t.datetime "updated_at", null: false
    t.index ["surgery_id", "surgery_procedure_id"], name: "index_surgery_procedure_selections_on_surgery_and_procedure", unique: true
    t.index ["surgery_id"], name: "index_surgery_procedure_selections_on_surgery_id"
    t.index ["surgery_procedure_id"], name: "index_surgery_procedure_selections_on_surgery_procedure_id"
  end

  create_table "surgery_procedures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_surgery_procedures_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "access_logs", "users"
  add_foreign_key "audit_events", "users"
  add_foreign_key "hospitalization_diagnoses", "diagnoses"
  add_foreign_key "hospitalization_diagnoses", "hospitalizations"
  add_foreign_key "hospitalizations", "patients"
  add_foreign_key "patient_diagnoses", "diagnoses"
  add_foreign_key "patient_diagnoses", "patients"
  add_foreign_key "surgeries", "hospitalizations"
  add_foreign_key "surgeries", "patients"
  add_foreign_key "surgery_diagnosis_links", "patient_diagnoses"
  add_foreign_key "surgery_diagnosis_links", "surgeries"
  add_foreign_key "surgery_procedure_selections", "surgeries"
  add_foreign_key "surgery_procedure_selections", "surgery_procedures"
end

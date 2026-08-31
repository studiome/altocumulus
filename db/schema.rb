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

ActiveRecord::Schema[8.1].define(version: 2026_08_31_065818) do
  create_table "diagnoses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_diagnoses_on_name", unique: true
  end

  create_table "elective_slot_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.integer "slot_count", null: false
    t.integer "slot_duration_minutes", null: false
    t.datetime "updated_at", null: false
    t.index ["day_of_week"], name: "index_elective_slot_rules_on_day_of_week", unique: true
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
    t.date "admission_date"
    t.datetime "created_at", null: false
    t.date "discharge_date"
    t.string "discharge_destination"
    t.string "outcome"
    t.integer "patient_id", null: false
    t.integer "planned_days"
    t.text "reason"
    t.string "room_preference"
    t.datetime "updated_at", null: false
    t.index ["discharge_date"], name: "index_hospitalizations_on_discharge_date"
    t.index ["patient_id", "admission_date"], name: "index_hospitalizations_on_patient_id_and_admission_date"
    t.index ["patient_id"], name: "index_hospitalizations_on_patient_id"
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
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "hospital_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["hospital_id"], name: "index_patients_on_hospital_id", unique: true
  end

  create_table "surgeries", force: :cascade do |t|
    t.string "anesthesia_method"
    t.datetime "created_at", null: false
    t.float "duration_hours"
    t.integer "hospitalization_id"
    t.integer "patient_id", null: false
    t.date "surgery_date"
    t.datetime "updated_at", null: false
    t.index ["hospitalization_id"], name: "index_surgeries_on_hospitalization_id"
    t.index ["patient_id"], name: "index_surgeries_on_patient_id"
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

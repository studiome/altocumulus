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

ActiveRecord::Schema[8.1].define(version: 2026_04_17_133000) do
  create_table "diagnoses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_diagnoses_on_name", unique: true
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
    t.string "laterality", default: "none", null: false
    t.integer "patient_id", null: false
    t.string "procedure"
    t.date "surgery_date"
    t.datetime "updated_at", null: false
    t.index ["patient_id"], name: "index_surgeries_on_patient_id"
  end

  create_table "surgery_diagnoses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "patient_diagnosis_id", null: false
    t.integer "surgery_id", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_diagnosis_id"], name: "index_surgery_diagnoses_on_patient_diagnosis_id"
    t.index ["surgery_id", "patient_diagnosis_id"], name: "index_surgery_diagnoses_on_surgery_id_and_patient_diagnosis_id", unique: true
    t.index ["surgery_id"], name: "index_surgery_diagnoses_on_surgery_id"
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

  add_foreign_key "patient_diagnoses", "diagnoses"
  add_foreign_key "patient_diagnoses", "patients"
  add_foreign_key "surgeries", "patients"
  add_foreign_key "surgery_diagnoses", "patient_diagnoses"
  add_foreign_key "surgery_diagnoses", "surgeries"
  add_foreign_key "surgery_procedure_selections", "surgeries"
  add_foreign_key "surgery_procedure_selections", "surgery_procedures"
end

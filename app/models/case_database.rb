require "csv"

# A named registry of patients with custom fields a data manager defines.
# See app/models/case_database_field.rb and app/models/case_database_entry.rb
# for the field definitions and per-patient values.
class CaseDatabase < ApplicationRecord
  include Auditable

  has_many :fields, -> { order(:position, :id) }, class_name: "CaseDatabaseField", dependent: :destroy
  has_many :entries, class_name: "CaseDatabaseEntry", dependent: :destroy
  has_many :patients, through: :entries

  validates :name, presence: true, uniqueness: true

  def to_s
    name
  end

  # UTF-8 BOM so Excel on a Japanese system doesn't read the file as
  # Shift_JIS and render mojibake (mirrors UserImport::UTF8_BOM).
  UTF8_BOM = "﻿".freeze

  def to_csv
    ordered_fields = fields.to_a
    ordered_entries = entries.includes(:patient).joins(:patient).order("patients.hospital_id")

    UTF8_BOM + CSV.generate do |csv|
      csv << [ I18n.t("patients.labels.hospital_id"), Patient.human_attribute_name(:name), *ordered_fields.map(&:label) ]
      ordered_entries.each do |entry|
        csv << [ entry.patient.hospital_id, entry.patient.name, *ordered_fields.map { |field| entry.value_for(field) } ]
      end
    end
  end
end

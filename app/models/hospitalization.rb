class Hospitalization < ApplicationRecord
  belongs_to :patient
  has_many :hospitalization_diagnoses, -> { order(:id) }, dependent: :destroy, inverse_of: :hospitalization
  has_many :diagnoses, through: :hospitalization_diagnoses

  accepts_nested_attributes_for :hospitalization_diagnoses,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["diagnosis_id"].blank? }

  validates :admission_date, presence: true
  validates :reason, presence: true
  validates :planned_days, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validate :must_have_at_least_one_diagnosis
  validate :no_duplicate_diagnoses

  def diagnosis_names_display
    active_hospitalization_diagnoses.filter_map(&:diagnosis_name).join("、").presence || "-"
  end

  def active_hospitalization_diagnoses
    hospitalization_diagnoses.reject(&:marked_for_destruction?)
  end

  private

    def diagnosis_ids_in_use
      active_hospitalization_diagnoses.filter_map(&:diagnosis_id)
    end

    def must_have_at_least_one_diagnosis
      return if diagnosis_ids_in_use.any?

      errors.add(:hospitalization_diagnoses, "must include at least one diagnosis")
    end

    def no_duplicate_diagnoses
      ids = diagnosis_ids_in_use
      return if ids.uniq.size == ids.size

      errors.add(:hospitalization_diagnoses, "must not include duplicate diagnoses")
    end
end

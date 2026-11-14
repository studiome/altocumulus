# The admissions-per-day warning threshold (入院数の目安) for one weekday. A
# weekday without a row uses the deploy-wide default
# (config.x.admission_warning_threshold); a Holiday row may override a single
# date (see AdmissionThreshold for the resolution order). It is a warning only
# and never blocks saving. Kept apart from ElectiveSlotRule on purpose: a
# weekday without surgery slots still needs a threshold.
class AdmissionThresholdRule < ApplicationRecord
  validates :day_of_week, presence: true, uniqueness: true, inclusion: { in: 0..6 }
  validates :threshold, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:day_of_week) }

  # Monday first, like SpecialSlotResource::WEEKDAY_ORDER.
  WEEKDAY_ORDER = [ 1, 2, 3, 4, 5, 6, 0 ].freeze

  def self.thresholds_by_day
    pluck(:day_of_week, :threshold).to_h
  end

  def self.default_threshold
    Rails.application.config.x.admission_warning_threshold
  end
end

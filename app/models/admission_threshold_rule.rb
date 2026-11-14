# The admissions-per-day warning threshold (入院数の目安) for one weekday. A
# weekday without a row uses the deploy-wide default
# (config.x.admission_warning_threshold); a Holiday row may override a single
# date (see AdmissionThreshold for the resolution order). It is a warning only
# and never blocks saving. Kept apart from ElectiveSlotRule on purpose: a
# weekday without surgery slots still needs a threshold.
class AdmissionThresholdRule < ApplicationRecord
  include LiveUpdatable
  validates :day_of_week, presence: true, uniqueness: true, inclusion: { in: 0..6 }
  validates :threshold, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:day_of_week) }

  # Monday first, like SpecialSlotResource::WEEKDAY_ORDER.
  WEEKDAY_ORDER = [ 1, 2, 3, 4, 5, 6, 0 ].freeze

  def self.thresholds_by_day
    pluck(:day_of_week, :threshold).to_h
  end

  # Saves the whole week from the admin form: `entries` maps weekday (0..6) to
  # the text typed. Blank deletes that weekday's row (it falls back to the
  # default). All or nothing: when any entry is invalid nothing is written and
  # the per-weekday error messages are returned ({} on success).
  def self.replace_week(entries)
    errors = {}
    transaction do
      (0..6).each do |day|
        text = entries[day].to_s.strip
        existing = find_by(day_of_week: day)
        if text.empty?
          existing&.destroy!
          next
        end

        rule = existing || new(day_of_week: day)
        rule.threshold = text
        errors[day] = rule.errors.full_messages_for(:threshold) unless rule.save
      end
      raise ActiveRecord::Rollback if errors.any?
    end
    errors
  end

  def self.default_threshold
    Rails.application.config.x.admission_warning_threshold
  end

  def live_update_all?
    true
  end

end

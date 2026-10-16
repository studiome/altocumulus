# A Holiday row does double duty: `holiday: true` (the default) is an actual
# closed day that shuts down elective slots (see ElectiveSlotUsage), while
# `holiday: false` is a plain day-comment that must never affect scheduling.
# A separate DateNote model was deliberately not introduced for this.
#
# A comment-only day can also override the weekday's slot rule for its date
# (列数): slot_count replaces the rule's count, and slot_duration_minutes, when
# given, its duration (required when the weekday has no rule to inherit it
# from). A closed day never carries an override.
class Holiday < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :name, presence: true, if: :holiday?
  validate :must_have_name_or_note_when_not_a_holiday
  validates :slot_count, numericality: { greater_than: 0 }, allow_nil: true
  validates :slot_duration_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :slot_override_only_on_open_days

  scope :ordered, -> { order(:date) }
  scope :between, ->(from, to) { where(date: from..to) }

  def self.by_date(dates)
    where(date: dates).index_by(&:date)
  end

  def self.filtered(year: nil)
    scope = all
    scope = scope.where(date: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31)) if year.present?
    scope
  end

  def self.available_years
    order(date: :desc).distinct.pluck(Arel.sql("strftime('%Y', date)")).map(&:to_i)
  end

  # Whether this row changes the day's slots: only a comment-only day with a
  # slot_count does (a closed day is closed, whatever else it carries).
  def slot_override?
    !holiday? && slot_count.present?
  end

  # slot_count as entered (e.g. "2.5"), without a trailing ".0".
  def slot_count_display
    slot_count&.round(1)&.to_s("F")&.sub(/\.0\z/, "")
  end

  # The rule to use for this date: the weekday's own, or -- when this row
  # overrides it -- an unsaved ElectiveSlotRule with the same interface
  # (slot_durations, total_slots, total_minutes...), so slot/capacity code
  # needs no special case. The weekday rule may be nil.
  def effective_rule_for(weekday_rule)
    return weekday_rule unless slot_override?

    ElectiveSlotRule.new(day_of_week: date.wday, slot_count: slot_count,
                         slot_duration_minutes: slot_duration_minutes || weekday_rule&.slot_duration_minutes)
  end

  def to_s
    "#{date} #{name.presence || note}"
  end

  private

    def slot_override_only_on_open_days
      if holiday?
        errors.add(:slot_count, :must_be_blank_on_a_closed_day) if slot_count.present?
        errors.add(:slot_duration_minutes, :must_be_blank_on_a_closed_day) if slot_duration_minutes.present?
        return
      end

      if slot_count.blank?
        errors.add(:slot_count, :required_with_slot_duration) if slot_duration_minutes.present?
      elsif slot_duration_minutes.blank? && date.present? && !ElectiveSlotRule.exists?(day_of_week: date.wday)
        errors.add(:slot_duration_minutes, :required_without_weekday_rule)
      end
    end

    def must_have_name_or_note_when_not_a_holiday
      return if holiday?
      return if name.present? || note.present?

      errors.add(:base, :must_have_name_or_note)
    end
end

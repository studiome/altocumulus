# A Holiday row does double duty: `holiday: true` (the default) is an actual
# closed day that shuts down elective slots (see ElectiveSlotUsage), while
# `holiday: false` is a plain day-comment that must never affect scheduling.
# A separate DateNote model was deliberately not introduced for this.
class Holiday < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :name, presence: true, if: :holiday?
  validate :must_have_name_or_note_when_not_a_holiday

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

  def to_s
    "#{date} #{name.presence || note}"
  end

  private

    def must_have_name_or_note_when_not_a_holiday
      return if holiday?
      return if name.present? || note.present?

      errors.add(:base, :must_have_name_or_note)
    end
end

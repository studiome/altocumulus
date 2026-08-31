class Holiday < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :name, presence: true

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
    "#{date} #{name}"
  end
end

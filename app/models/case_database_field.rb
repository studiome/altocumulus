class CaseDatabaseField < ApplicationRecord
  FIELD_TYPES = %w[text number select].freeze

  belongs_to :case_database

  validates :label, presence: true, uniqueness: { scope: :case_database_id }
  validates :field_type, inclusion: { in: FIELD_TYPES }
  validate :select_requires_at_least_one_option

  scope :ordered, -> { order(:position, :id) }

  def self.field_type_options
    FIELD_TYPES.index_with { |key| I18n.t("models.case_database_field.field_type_options.#{key}") }
  end

  def self.field_type_form_options
    field_type_options.map { |k, v| [ v, k ] }
  end

  # Splits `options` (one choice per line) into a clean list: strips
  # whitespace, drops blank lines, and removes duplicates.
  def option_list
    options.to_s.split("\n").map(&:strip).reject(&:blank?).uniq
  end

  def to_s
    label
  end

  private

    def select_requires_at_least_one_option
      return unless field_type == "select"

      errors.add(:options, :blank) if option_list.empty?
    end
end

# A department's care team (担当チーム). Hospitalizations and surgeries are
# assigned to a team; who is on the team changes every few months, which is
# modelled by TeamTerm (a date range) and TeamTermMember (the people of that
# term). Only used while the site config turns features.teams on.
class Team < ApplicationRecord
  include MasterRecord

  # A fixed palette of generic color keys, labelled through i18n
  # (models.team.color_options.*) and shown as a badge. The classes are written
  # out in full so Tailwind sees them.
  COLOR_KEYS = %w[blue red green orange purple teal gray].freeze
  BADGE_CLASSES = {
    "blue" => "border-transparent bg-blue-600 text-white",
    "red" => "border-transparent bg-red-600 text-white",
    "green" => "border-transparent bg-green-600 text-white",
    "orange" => "border-transparent bg-orange-500 text-white",
    "purple" => "border-transparent bg-purple-600 text-white",
    "teal" => "border-transparent bg-teal-600 text-white",
    "gray" => "border-transparent bg-gray-500 text-white"
  }.freeze

  # Declared before team_terms so a referenced team is refused before its
  # terms are destroyed.
  has_many :hospitalizations, dependent: :restrict_with_error
  has_many :surgeries, dependent: :restrict_with_error
  has_many :team_terms, -> { order(:starts_on) }, dependent: :destroy, inverse_of: :team

  validates :color, inclusion: { in: COLOR_KEYS }

  class << self
    def extra_form_attributes
      [ :color ]
    end

    def color_options
      COLOR_KEYS.index_with { |key| I18n.t("models.team.color_options.#{key}") }
    end

    def color_form_options
      color_options.map { |key, label| [ label, key ] }
    end
  end

  def color_label
    self.class.color_options[color] || color
  end

  def badge_class
    BADGE_CLASSES.fetch(color, BADGE_CLASSES["gray"])
  end

  # The term whose date range covers the date, if any.
  def term_for(date)
    return nil if date.blank?

    team_terms.includes(:team_term_members).find_by("starts_on <= :date AND ends_on >= :date", date: date)
  end
end

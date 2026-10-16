# One person of a TeamTerm. user is optional because some members have no
# account of their own; the name is what is shown (it defaults to the user's
# name when a user is chosen and the name left blank).
class TeamTermMember < ApplicationRecord
  ROLE_KEYS = %w[main sub member].freeze

  belongs_to :team_term
  belongs_to :user, optional: true

  normalizes :name, with: ->(name) { name.to_s.strip }

  before_validation :default_name_from_user

  validates :name, presence: true
  validates :role, inclusion: { in: ROLE_KEYS }

  def self.role_options
    ROLE_KEYS.index_with { |key| I18n.t("models.team_term_member.role_options.#{key}") }
  end

  def self.role_form_options
    role_options.map { |key, label| [ label, key ] }
  end

  def role_label
    self.class.role_options[role] || role
  end

  # Compact marker for lists, e.g. "M" / "S"; blank for a plain member.
  def role_abbreviation
    I18n.t("models.team_term_member.role_abbreviations.#{role}", default: "")
  end

  def role_rank
    ROLE_KEYS.index(role) || ROLE_KEYS.size
  end

  def display_label
    abbreviation = role_abbreviation
    abbreviation.present? ? "#{name}(#{abbreviation})" : name
  end

  def to_s
    name.to_s
  end

  private

    def default_name_from_user
      self.name = user.name if name.blank? && user
    end
end

class User < ApplicationRecord
  has_secure_password

  ROLES = %w[user admin].freeze
  LOCALES = %w[en ja].freeze

  # Not a column: AccountsController attaches a validation error to this
  # attribute (:current_password, :incorrect) when re-authentication for a
  # password change fails. Declaring it as a real attribute is what lets
  # ActiveModel::Errors#generate_message read its value (via
  # read_attribute_for_validation) when building the localized message --
  # without this, attaching a *symbol* error type (needed for i18n) to a
  # non-existent method raises NoMethodError. A literal String message
  # didn't need this, since that path skips value interpolation entirely,
  # which is why this went unnoticed before the i18n conversion.
  attr_accessor :current_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :locale, inclusion: { in: LOCALES }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :cannot_deactivate_or_demote_last_admin, on: :update

  scope :active, -> { where(active: true) }

  def admin?
    role == "admin"
  end

  def active?
    active
  end

  def to_s
    name
  end

  private

  def cannot_deactivate_or_demote_last_admin
    return unless role_was == "admin" && active_was
    return if role == "admin" && active?

    other_active_admins = User.active.where(role: "admin").where.not(id: id)
    errors.add(:base, :cannot_remove_last_admin) if other_active_admins.none?
  end
end

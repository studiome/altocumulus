class User < ApplicationRecord
  has_secure_password

  ROLES = %w[user admin].freeze
  LOCALES = %w[en ja].freeze

  # Which shape a login_id must take, server-configured via
  # config.x.account_identifier (see config/application.rb). Only two modes
  # are supported; anything else falls back to "email" (see
  # .identifier_mode).
  IDENTIFIER_MODES = %w[email username].freeze
  USERNAME_FORMAT = /\A[a-z0-9._-]{3,32}\z/

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

  normalizes :login_id, with: ->(login_id) { login_id.strip.downcase }

  validates :login_id, presence: true, uniqueness: { case_sensitive: false }
  validates :login_id, format: { with: URI::MailTo::EMAIL_REGEXP, message: :invalid_email_format, allow_blank: true },
                        if: -> { self.class.identifier_email? }
  validates :login_id, format: { with: USERNAME_FORMAT, message: :invalid_username_format, allow_blank: true },
                        if: -> { self.class.identifier_username? }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :locale, inclusion: { in: LOCALES }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :cannot_deactivate_or_demote_last_admin, on: :update

  scope :active, -> { where(active: true) }

  # The server's configured login_id shape. Falls back to "email" for an
  # unrecognized ACCOUNT_IDENTIFIER value rather than raising, since this is
  # read on every request (form rendering, login, validation).
  def self.identifier_mode
    mode = Rails.application.config.x.account_identifier.to_s
    IDENTIFIER_MODES.include?(mode) ? mode : "email"
  end

  def self.identifier_email?
    identifier_mode == "email"
  end

  def self.identifier_username?
    identifier_mode == "username"
  end

  # Overridden so :login_id's label follows the server's identifier_mode
  # ("Email"/"メールアドレス" vs. "Username"/"ユーザー名") everywhere it's
  # rendered automatically: form.label, error full_message, etc. Every
  # other attribute keeps Rails' normal lookup via `super`.
  def self.human_attribute_name(attribute, options = {})
    return I18n.t("models.user.login_id_labels.#{identifier_mode}") if attribute.to_s == "login_id"

    super
  end

  def self.role_options
    ROLES.index_with { |key| I18n.t("models.user.role_options.#{key}") }
  end

  def self.role_form_options
    role_options.map { |k, v| [ v, k ] }
  end

  def admin?
    role == "admin"
  end

  def active?
    active
  end

  def role_label
    self.class.role_options[role] || role
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

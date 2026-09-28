class User < ApplicationRecord
  has_secure_password

  # A user's roles live in the has_many :user_roles join table (one row per
  # held role key) rather than one column per role, so a user can hold
  # several roles at once (e.g. admin AND data_manager) and adding a new
  # role to the system is just adding a key here (+ an i18n label at
  # models.user.role_options.<key> in en/ja) -- no migration needed. "admin"
  # and "data_manager" each grant their own extra privileges: an admin
  # manages users/announcements/settings, while data_manager is the only
  # role that may create/edit/delete case databases, their fields, and
  # remove a patient entry from one (see
  # ApplicationController#require_data_manager and CaseDatabase*Controllers)
  # -- everything else about a case database (viewing, adding a patient,
  # entering values, exporting CSV) is open to every signed-in role, same as
  # "user". "user" itself grants no privilege beyond being signed in.
  ROLES = %w[user data_manager admin].freeze
  LOCALES = %w[en ja].freeze

  has_many :user_roles, dependent: :destroy, autosave: true

  # A brand new User left otherwise unconfigured should still come out as an
  # ordinary "user", matching the old single `role` column's default of
  # "user". Only applies when nothing has built/assigned roles yet, so
  # explicitly assigning `roles=` (even to []) in the constructor overrides
  # it -- see #roles=.
  after_initialize :set_default_role

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
  validates :roles, presence: true
  validates :locale, inclusion: { in: LOCALES }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :roles_must_be_known
  validate :cannot_deactivate_or_demote_last_admin, on: :update

  scope :active, -> { where(active: true) }
  scope :with_role, ->(key) { where(id: UserRole.where(role: key.to_s).select(:user_id)) }
  scope :admins, -> { with_role("admin") }

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

  # Held role keys, in ROLES order (not insertion order), e.g. %w[user admin].
  # Reads the in-memory association (not a DB query), so a not-yet-saved
  # #roles= change is reflected immediately -- rows marked for destruction
  # (about to be removed on save) are excluded.
  def roles
    held = user_roles.reject(&:marked_for_destruction?).map(&:role)
    ROLES.select { |key| held.include?(key) }
  end

  # Accepts an array of role keys (strings or symbols); blanks are ignored
  # (collection_check_boxes always submits a blank hidden value alongside
  # any checked boxes). Unknown keys are kept aside for #roles_must_be_known
  # to turn into a validation error, rather than being silently dropped.
  #
  # Works entirely in memory (building new UserRole rows / marking existing
  # ones for destruction) so validations -- and a second call to #roles= --
  # see the change before save; autosave: true on the association persists
  # it when the user itself is saved.
  def roles=(keys)
    @roles_assigned = true
    keys = Array(keys).map(&:to_s).reject(&:blank?)
    @unknown_role_keys = keys - ROLES
    known_keys = keys & ROLES

    current = user_roles.reject(&:marked_for_destruction?)
    current.each { |user_role| user_role.mark_for_destruction unless known_keys.include?(user_role.role) }

    remaining_keys = current.reject(&:marked_for_destruction?).map(&:role)
    (known_keys - remaining_keys).each { |key| user_roles.build(role: key) }
  end

  def has_role?(key)
    roles.include?(key.to_s)
  end

  def admin?
    has_role?("admin")
  end

  def data_manager?
    has_role?("data_manager")
  end

  def user_role?
    has_role?("user")
  end

  def active?
    active
  end

  def role_labels
    roles.map { |key| self.class.role_options[key] || key }
  end

  def to_s
    name
  end

  private

  def set_default_role
    return unless new_record?
    return if @roles_assigned
    return if user_roles.any?

    self.roles = %w[user]
  end

  def roles_must_be_known
    return if @unknown_role_keys.blank?

    errors.add(:roles, :inclusion, value: @unknown_role_keys.join(", "))
  end

  # role_admin_was/active_was no longer exist as column-backed methods now
  # that roles live in a join table, so "was admin before this change" is
  # read from the persisted (loaded-from-DB) user_roles rows, independent of
  # any not-yet-saved #roles= change -- compared against the current
  # in-memory #roles.
  def cannot_deactivate_or_demote_last_admin
    return unless active_was

    persisted_roles = user_roles.select(&:persisted?).map(&:role)
    return unless persisted_roles.include?("admin")
    return if roles.include?("admin") && active?

    other_active_admins = User.active.admins.where.not(id: id)
    errors.add(:base, :cannot_remove_last_admin) if other_active_admins.none?
  end
end

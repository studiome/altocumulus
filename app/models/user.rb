class User < ApplicationRecord
  has_secure_password

  ROLES = %w[user admin].freeze

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
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
    errors.add(:base, "Cannot remove the last active admin") if other_active_admins.none?
  end
end

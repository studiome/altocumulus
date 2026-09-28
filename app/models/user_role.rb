# One row per role a User holds (see User::ROLES). Adding a new role to the
# system is just adding a key to User::ROLES (+ an i18n label) -- no schema
# change, since this join table stores role keys as plain strings rather
# than one boolean column per role.
class UserRole < ApplicationRecord
  belongs_to :user

  validates :role, inclusion: { in: User::ROLES }
  validates :role, uniqueness: { scope: :user_id }
end

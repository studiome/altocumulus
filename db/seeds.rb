# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Bootstrap the very first administrator. Only runs when BOTH env vars are
# present, and never touches the password of a user that already exists, so
# re-running `db:seed` in production is always safe.
# BOOTSTRAP_ADMIN_LOGIN_ID is the current name; BOOTSTRAP_ADMIN_EMAIL is kept
# as a fallback for deployments that set it from before the login id could
# be a username.
bootstrap_admin_login_id = ENV["BOOTSTRAP_ADMIN_LOGIN_ID"] || ENV["BOOTSTRAP_ADMIN_EMAIL"]
bootstrap_admin_password = ENV["BOOTSTRAP_ADMIN_PASSWORD"]

if bootstrap_admin_login_id.present? && bootstrap_admin_password.present?
  User.find_or_create_by!(login_id: bootstrap_admin_login_id) do |user|
    user.name = "Administrator"
    user.password = bootstrap_admin_password
    user.role = "admin"
    user.active = true
  end
end

if Rails.env.development?
  demo_admin_login_id = User.identifier_email? ? "admin@example.com" : "admin"

  User.find_or_create_by!(login_id: demo_admin_login_id) do |user|
    user.name = "Demo Admin"
    user.password = "password"
    user.role = "admin"
    user.active = true
  end
end

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
bootstrap_admin_email = ENV["BOOTSTRAP_ADMIN_EMAIL"]
bootstrap_admin_password = ENV["BOOTSTRAP_ADMIN_PASSWORD"]

if bootstrap_admin_email.present? && bootstrap_admin_password.present?
  User.find_or_create_by!(email: bootstrap_admin_email) do |user|
    user.name = "Administrator"
    user.password = bootstrap_admin_password
    user.role = "admin"
    user.active = true
  end
end

if Rails.env.development?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.name = "Demo Admin"
    user.password = "password"
    user.role = "admin"
    user.active = true
  end
end

# Makes sure the names listed under `masters` in the site config exist in the
# admin-editable master tables. Idempotent and strictly additive: it only
# creates missing rows (appended after the existing ones, in the order the
# file lists them) and never renames, reorders, reactivates or deletes
# anything an admin has since changed. Run by `bin/rails site:seed_masters`
# and by db/seeds.rb.
class SiteMasterSeeder
  MODELS = {
    "departments" => "Department",
    "surgery_locations" => "SurgeryLocation",
    "surgical_devices" => "SurgicalDevice"
  }.freeze

  # Returns how many rows were created per master key.
  def self.call(config = SiteConfig.current)
    MODELS.to_h do |key, class_name|
      model = class_name.constantize
      created = config.master_names(key).count do |name|
        next false if model.exists?(name: name)

        model.create!(name: name)
        true
      end
      [ key, created ]
    end
  end
end

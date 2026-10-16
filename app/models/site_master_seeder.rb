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

        model.create!(name: name, **extra_attributes(key, name, config))
        true
      end
      [ key, created ]
    end
  end

  # Options a site config can set on a newly created row (only ever applied on
  # creation, so a later admin edit is never overwritten).
  def self.extra_attributes(key, name, config)
    if key == "surgery_locations" && config.surgery_locations_asking_performing_department.include?(name)
      { asks_performing_department: true }
    else
      {}
    end
  end
  private_class_method :extra_attributes
end

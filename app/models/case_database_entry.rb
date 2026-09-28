class CaseDatabaseEntry < ApplicationRecord
  belongs_to :case_database
  belongs_to :patient

  validates :patient_id, uniqueness: { scope: :case_database_id }
  validate :field_values_are_valid_for_their_fields

  # Reads the stored value for one field. Values are stored as strings keyed
  # by the field's id (as a string), since `field_values` is a plain JSON
  # hash with no schema of its own.
  def value_for(field)
    field_values[field.id.to_s]
  end

  # Merges `new_values` (a hash of field id (string) => value) into the
  # existing field_values, ignoring any key that is not one of this
  # database's fields. Blank values are kept (allowed), not stripped.
  def assign_field_values(new_values)
    return if new_values.blank?

    valid_field_ids = case_database.fields.pluck(:id).map(&:to_s)
    filtered = new_values.to_h.stringify_keys.slice(*valid_field_ids)
    self.field_values = field_values.merge(filtered)
  end

  private

    def field_values_are_valid_for_their_fields
      return if case_database.nil?

      case_database.fields.each do |field|
        value = field_values[field.id.to_s]
        next if value.blank?

        case field.field_type
        when "number"
          unless Float(value, exception: false)
            errors.add(:field_values, :invalid_number, field: field.label)
          end
        when "select"
          unless field.option_list.include?(value)
            errors.add(:field_values, :invalid_option, field: field.label)
          end
        end
      end
    end
end

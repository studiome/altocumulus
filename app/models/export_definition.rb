# A named CSV export (a key of the `exports` site config): which kind of
# record its rows are and which ExportFields make up its columns, in order.
#
#   key      Symbol, /\A[a-z0-9_]+\z/; also the file name's prefix
#   subject  :surgery or :hospitalization
#   fields   the ExportField keys (Symbols)
#   label    the button text the site gave it, or nil for the translated
#            default (exports.labels.<key>, else the humanized key)
ExportDefinition = Data.define(:key, :subject, :fields, :label) do
  # The built-in exports used when the site config has no `exports`: every
  # field of the subject (team fields only when the teams feature is on).
  def self.defaults(teams_enabled:)
    {
      surgery_list: :surgery,
      admission_list: :hospitalization
    }.map do |key, subject|
      fields = ExportField.registry.values.select { |field| field.subject == subject && (teams_enabled || !field.teams?) }
      new(key: key, subject: subject, fields: fields.map(&:key), label: nil)
    end
  end

  def export_fields
    fields.map { |field_key| ExportField.find(subject, field_key) }
  end

  def title
    label.presence || I18n.t("exports.labels.#{key}", default: key.to_s.humanize)
  end

  def includes
    ExportField.includes_for(export_fields)
  end

  def surgery?
    subject == :surgery
  end
end

ExportDefinition::KEY_FORMAT = /\A[a-z0-9_]+\z/

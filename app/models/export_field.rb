# One column of a CSV export (see ExportDefinition, the `exports` site config).
# Unlike a LedgerColumn (stacked, two-tier cells for the screen/PDF) an export
# field yields exactly one plain value per record, so a spreadsheet can sort
# and filter on it. The registry below is what `exports.<name>.fields` is
# validated against, per subject (the kind of record a row is):
#   :surgery          one row per Surgery
#   :hospitalization  one row per Hospitalization
#
# A field knows its key, its (translated) header, the associations its value
# reads (`includes`, relative to the subject, so an export preloads exactly
# what it shows) and whether it needs features.teams. Values are Strings, or
# nil when there is nothing to show (never "-"): a blank CSV cell.
class ExportField
  SUBJECTS = %i[surgery hospitalization].freeze

  # Associations a team value reads (see TeamAssignable / Team#term_for).
  TEAM_INCLUDES = LedgerColumns::Cells::TEAM_INCLUDES

  attr_reader :subject, :key

  def initialize(subject:, key:, includes: [], teams: false, &value)
    @subject = subject
    @key = key
    @includes = includes
    @teams = teams
    @value = value
  end

  def teams?
    @teams
  end

  def header
    I18n.t("export_fields.headers.#{key}")
  end

  def includes
    @includes.dup
  end

  # The cell text for `record`, or nil.
  def value(record)
    result = @value.call(record)
    result.nil? ? nil : result.to_s.presence
  end

  class << self
    def registry
      @registry ||= (ExportFields::SurgeryFields.all + ExportFields::HospitalizationFields.all)
                    .index_by { |field| [ field.subject, field.key ] }.freeze
    end

    def keys(subject)
      registry.keys.select { |(field_subject, _)| field_subject == subject.to_sym }.map(&:last)
    end

    def find(subject, key)
      registry.fetch([ subject.to_sym, key.to_sym ])
    end

    def includes_for(fields)
      fields.flat_map(&:includes).uniq
    end
  end
end

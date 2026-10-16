# One column of a ledger table, shared by every screen that lists cases in
# ledger form: the operations calendar (HTML), the weekly surgery PDF and the
# future examination-admission calendar. A column knows its header (two tiers:
# an upper label and an optional lower label), its default PDF width and how to
# build a renderer-neutral Cell from a record.
#
# Which columns a ledger shows, and in what order, comes from the site config
# (ledger_columns.<ledger>, see SiteConfig); this class is the registry the
# config is validated against and resolved through.
#
# A Cell has an upper and a lower part, each a list of Segments. A segment is
# text plus a `kind` that tells the renderer how to dress it:
#   text kinds:  :primary, :secondary, :mono (primary-sized monospace),
#                :secondary_mono
#   badge kinds: :scheduling, :emergency, :off_slot, :partner_department,
#                :location, :transfer, :device, :team, :missing
# The HTML renderer (LedgerHelper) maps kinds to daisyUI classes; the PDF
# flattens them to plain text (Cell#plain_text), so it stays monochrome.
class LedgerColumn
  TEXT_KINDS = %i[primary secondary mono secondary_mono].freeze
  BADGE_KINDS = %i[scheduling emergency off_slot partner_department location transfer device team missing].freeze

  # `href` links the text (HTML only); `color` is a Team color key for :team.
  Segment = Struct.new(:text, :kind, :href, :color) do
    def badge?
      LedgerColumn::BADGE_KINDS.include?(kind)
    end
  end

  Cell = Struct.new(:upper, :lower, keyword_init: true) do
    def initialize(upper: [], lower: [])
      super
    end

    def empty?
      upper.empty? && lower.empty?
    end

    def badges?
      (upper + lower).any?(&:badge?)
    end

    # The PDF's view: segments of a part joined with the list separator, the
    # two parts on separate lines.
    def plain_text
      separator = I18n.t("common.list_separator")
      [ upper, lower ].map { |part| part.map(&:text).join(separator) }.reject(&:blank?).join("\n")
    end
  end

  # What a builder may need beyond the record: the referral lookup for
  # surgeries not linked to a hospitalization, and a callable returning the
  # link target of a record (nil/absent = no link, as in the PDF).
  Context = Data.define(:referral_lookup, :href) do
    def initialize(referral_lookup: nil, href: nil)
      super
    end

    def href_for(record)
      href&.call(record)
    end
  end

  # ledger => the kind of record its rows are, and the columns shown when the
  # site config does not say otherwise.
  LEDGERS = {
    operations_calendar: {
      subject: :surgery,
      default: %i[time_slot patient diagnosis_procedure operator_assistant duration_anesthesia category referral_adl]
    },
    weekly_pdf: {
      subject: :surgery,
      default: %i[time_slot patient diagnosis_procedure operator_assistant duration_anesthesia category referral_adl]
    },
    examination_calendar: {
      subject: :hospitalization,
      default: %i[admission_dates patient age_sex diagnosis_procedure_name purpose reservation referral_adl status]
    }
  }.freeze

  # Columns that only make sense with features.teams on.
  TEAM_COLUMN = :team

  attr_reader :key, :subject, :width, :css_class

  def initialize(subject:, key:, width:, css_class: nil, includes: [], &builder)
    @subject = subject
    @key = key
    @width = width
    @css_class = css_class
    @includes = includes
    @builder = builder
  end

  def header_upper
    I18n.t("ledger_columns.headers.#{key}.upper")
  end

  def header_lower
    I18n.t("ledger_columns.headers.#{key}.lower", default: nil)
  end

  # Associations (relative to the subject) the builder reads.
  def includes
    @includes.dup
  end

  def cell(record, context = Context.new)
    @builder.call(record, context)
  end

  class << self
    def registry
      @registry ||= (LedgerColumns::SurgeryColumns.all + LedgerColumns::HospitalizationColumns.all)
                    .index_by { |column| [ column.subject, column.key ] }.freeze
    end

    def keys(subject)
      registry.keys.select { |(column_subject, _)| column_subject == subject }.map(&:last)
    end

    def find(subject, key)
      registry.fetch([ subject.to_sym, key.to_sym ])
    end

    def ledger_names
      LEDGERS.keys
    end

    def subject_for(ledger)
      LEDGERS.fetch(ledger.to_sym).fetch(:subject)
    end

    def default_keys(ledger)
      LEDGERS.fetch(ledger.to_sym).fetch(:default)
    end

    # The columns the site config picked for the ledger (its built-in default
    # when the config does not mention it), in order.
    def for_ledger(ledger)
      subject = subject_for(ledger)
      SiteConfig.current.ledger_column_keys(ledger).map { |key| find(subject, key) }
    end

    # Association list for Model.includes(*...) covering the given columns.
    def includes_for(columns)
      columns.flat_map(&:includes).uniq
    end
  end
end

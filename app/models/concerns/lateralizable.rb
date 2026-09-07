module Lateralizable
  extend ActiveSupport::Concern

  # Only the valid DB keys live here -- labels come from
  # config/locales/*.yml (models.lateralizable.laterality_options), shared by
  # every model that includes this concern (PatientDiagnosis,
  # SurgeryProcedureSelection).
  LATERALITY_KEYS = %w[right left bilateral none].freeze

  # A module method (not inside class_methods) so it is reachable both as
  # Lateralizable.laterality_options from outside an including class (e.g.
  # PatientDiagnosis#display_name) and as the shared implementation behind
  # the including class's own .laterality_form_options below.
  def self.laterality_options
    LATERALITY_KEYS.index_with { |key| I18n.t("models.lateralizable.laterality_options.#{key}") }
  end

  included do
    validates :laterality, inclusion: { in: Lateralizable::LATERALITY_KEYS }
  end

  class_methods do
    def laterality_form_options
      Lateralizable.laterality_options.map { |k, v| [ v, k ] }
    end
  end

  def laterality_label
    Lateralizable.laterality_options[laterality] || Lateralizable.laterality_options["none"]
  end
end

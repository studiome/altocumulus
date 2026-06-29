module Lateralizable
  extend ActiveSupport::Concern

  LATERALITY_OPTIONS = {
    "right" => "Right",
    "left" => "Left",
    "bilateral" => "Bilateral",
    "none" => "None"
  }.freeze

  included do
    validates :laterality, inclusion: { in: Lateralizable::LATERALITY_OPTIONS.keys }
  end

  class_methods do
    def laterality_form_options
      Lateralizable::LATERALITY_OPTIONS.map { |k, v| [v, k] }
    end
  end

  def laterality_label
    Lateralizable::LATERALITY_OPTIONS[laterality] || "None"
  end
end

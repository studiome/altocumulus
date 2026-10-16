# A master (SurgeryLocation, SurgicalDevice) that may be a special slot
# resource: it carries weekly lane counts (SpecialSlotRule). A case using it
# keeps its regular slot and also takes one lane here. A resource without any
# positive count is an ordinary master, merely recorded on cases.
module SpecialSlotResource
  extend ActiveSupport::Concern

  # Weekdays in the order the admin form lists them (Monday first).
  WEEKDAY_ORDER = [ 1, 2, 3, 4, 5, 6, 0 ].freeze

  included do
    has_many :special_slot_rules, as: :resource, dependent: :destroy, autosave: true
  end

  class_methods do
    def extra_form_attributes
      super + [ { special_slot_counts: SpecialSlotResource::WEEKDAY_ORDER.map(&:to_s) } ]
    end
  end

  # {weekday (0 = Sunday) => lanes}, only the weekdays that have lanes.
  def special_slot_counts
    special_slot_rules.reject(&:marked_for_destruction?).select { |rule| rule.slot_count.to_i.positive? }
                      .sort_by(&:day_of_week).to_h { |rule| [ rule.day_of_week, rule.slot_count ] }
  end

  def special_slot_count_on(weekday)
    special_slot_counts.fetch(weekday, 0)
  end

  def special_slot_resource?
    special_slot_counts.any?
  end

  # Takes {"1" => "2", "2" => ""...} (the form): blank or 0 removes the
  # weekday's rule, a whole number sets it, anything else is kept as typed so
  # the rule fails validation. Weekdays left out are not touched.
  def special_slot_counts=(counts)
    counts = counts.to_unsafe_h if counts.respond_to?(:to_unsafe_h)
    counts.to_h.each do |weekday, raw|
      weekday = Integer(weekday, exception: false)
      next unless weekday

      rule = special_slot_rules.find { |existing| existing.day_of_week == weekday }
      value = raw.to_s.strip
      if value.empty? || value.match?(/\A0+\z/)
        rule&.mark_for_destruction
      else
        rule ||= special_slot_rules.build(day_of_week: weekday)
        rule.slot_count = value
      end
    end
  end
end

# Represents how a single day's elective surgery slots (see ElectiveSlotRule)
# are being used. 1 surgery = 1 slot: a surgery that runs longer than the
# slot's duration is treated as extending its own slot, never as consuming a
# second one and never as invalid. Emergency surgeries are tracked
# separately and never affect slot usage or warnings.
class ElectiveSlotUsage
  attr_reader :date, :rule, :elective_surgeries, :emergency_surgeries

  # Builds one ElectiveSlotUsage per date in a single pass, issuing a fixed
  # number of queries regardless of how many dates are given (no N+1).
  def self.for_dates(dates)
    dates = dates.to_a
    rules = ElectiveSlotRule.by_day_of_week
    surgeries_by_date = Surgery.where(surgery_date: dates)
                                .includes(:patient, { surgery_procedure_selections: :surgery_procedure })
                                .group_by(&:surgery_date)

    dates.index_with do |date|
      day_surgeries = surgeries_by_date[date] || []
      new(
        date: date,
        rule: rules[date.wday],
        elective_surgeries: day_surgeries.select(&:elective?),
        emergency_surgeries: day_surgeries.select(&:emergency?)
      )
    end
  end

  def initialize(date:, rule:, elective_surgeries:, emergency_surgeries:)
    @date = date
    @rule = rule
    @elective_surgeries = elective_surgeries
    @emergency_surgeries = emergency_surgeries
  end

  def configured?
    rule.present?
  end

  def slot_count
    rule&.slot_count || 0
  end

  def slot_duration_minutes
    rule&.slot_duration_minutes
  end

  def used_slots
    elective_surgeries.size
  end

  def remaining_slots
    [ slot_count - used_slots, 0 ].max
  end

  def over_capacity?
    used_slots > slot_count
  end

  def over_capacity_count
    [ used_slots - slot_count, 0 ].max
  end

  def overrunning_surgeries
    return [] unless rule

    elective_surgeries.select { |surgery| surgery.slot_overrun?(rule) }
  end

  def warnings
    messages = []

    if !configured? && elective_surgeries.any?
      messages << "No elective slots are configured for #{date.strftime('%A')}."
    end

    if over_capacity?
      messages << "Over capacity: #{used_slots} elective surgeries in #{slot_count} slots."
    end

    if overrunning_surgeries.any?
      count = overrunning_surgeries.size
      noun = count == 1 ? "surgery" : "surgeries"
      verb = count == 1 ? "runs" : "run"
      messages << "#{count} #{noun} #{verb} past its #{slot_duration_minutes} min slot."
    end

    messages
  end
end

# Represents how a single day's elective surgery slots (see ElectiveSlotRule)
# are being used. 1 surgery = 1 slot: a surgery that runs longer than the
# slot's duration is treated as extending its own slot, never as consuming a
# second one and never as invalid. Emergency surgeries are tracked
# separately and never affect slot usage or warnings.
class ElectiveSlotUsage
  attr_reader :date, :rule, :elective_surgeries, :emergency_surgeries, :holiday

  # Builds one ElectiveSlotUsage per date in a single pass, issuing a fixed
  # number of queries regardless of how many dates are given (no N+1).
  def self.for_dates(dates)
    dates = dates.to_a
    rules = ElectiveSlotRule.by_day_of_week
    holidays = Holiday.by_date(dates)
    surgeries_by_date = Surgery.where(surgery_date: dates)
                                .includes(:patient, { surgery_procedure_selections: :surgery_procedure })
                                .order(:start_time, :id)
                                .group_by(&:surgery_date)

    dates.index_with do |date|
      day_surgeries = surgeries_by_date[date] || []
      new(
        date: date,
        rule: rules[date.wday],
        elective_surgeries: day_surgeries.select(&:elective?),
        emergency_surgeries: day_surgeries.select(&:emergency?),
        holiday: holidays[date]
      )
    end
  end

  def initialize(date:, rule:, elective_surgeries:, emergency_surgeries:, holiday: nil)
    @date = date
    @rule = rule
    @elective_surgeries = elective_surgeries
    @emergency_surgeries = emergency_surgeries
    @holiday = holiday
  end

  def holiday?
    holiday.present?
  end

  # The rule to actually apply for elective slots. A holiday shuts down
  # elective slots for the day regardless of the weekday rule; emergency
  # surgeries never consult this and are never affected.
  def effective_rule
    holiday? ? nil : rule
  end

  def configured?
    effective_rule.present?
  end

  def slot_count
    effective_rule&.slot_count || 0
  end

  def slot_duration_minutes
    effective_rule&.slot_duration_minutes
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
    return [] unless effective_rule

    elective_surgeries.select { |surgery| surgery.slot_overrun?(effective_rule) }
  end

  def warnings
    messages = []

    if holiday? && elective_surgeries.any?
      messages << "#{holiday.name} is a holiday: no elective slots are available."
    elsif !configured? && elective_surgeries.any?
      messages << "No elective slots are configured for #{date.strftime('%A')}."
    end

    if over_capacity?
      messages << "Over capacity: #{used_slots} elective surgeries in #{slot_count} slots."
    end

    if overrunning_surgeries.any?
      count = overrunning_surgeries.size
      clause = if count == 1
        "1 surgery runs past its"
      else
        "#{count} surgeries run past their"
      end
      slot = count == 1 ? "slot" : "slots"
      messages << "#{clause} #{slot_duration_minutes} min #{slot}."
    end

    messages
  end
end

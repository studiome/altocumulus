# Represents how a single day's elective surgery slots (see ElectiveSlotRule)
# are being used. A slot is a block of operating room time for the day, not a
# single operation: several surgeries are expected to share one slot, and a
# slot is only over its limit when the surgeries booked into it add up to more
# than the slot's duration. Surgeries are placed by their own slot_number, so
# an unassigned surgery waits outside the slots rather than filling one.
# Emergency surgeries are tracked separately and never affect slot usage or
# warnings.
class ElectiveSlotUsage
  # One slot of the day, holding every surgery assigned to it.
  class Slot
    attr_reader :number, :surgeries, :duration_minutes

    def initialize(number:, surgeries:, duration_minutes:)
      @number = number
      @surgeries = surgeries
      @duration_minutes = duration_minutes
    end

    def empty?
      surgeries.empty?
    end

    def used_minutes
      @used_minutes ||= surgeries.sum { |surgery| surgery.duration_minutes || 0 }
    end

    def remaining_minutes
      [ duration_minutes - used_minutes, 0 ].max
    end

    def overrun_minutes
      over = used_minutes - duration_minutes
      over.positive? ? over : nil
    end

    def overrun?
      overrun_minutes.present?
    end
  end

  attr_reader :date, :rule, :elective_surgeries, :emergency_surgeries, :holiday

  # Builds one ElectiveSlotUsage per date in a single pass, issuing a fixed
  # number of queries regardless of how many dates are given (no N+1).
  def self.for_dates(dates)
    dates = dates.to_a
    rules = ElectiveSlotRule.by_day_of_week
    holidays = Holiday.by_date(dates)
    surgeries_by_date = Surgery.where(surgery_date: dates)
                                .includes(:patient, { surgery_procedure_selections: :surgery_procedure })
                                .order(:slot_number, :start_time, :id)
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

  def capacity_minutes
    effective_rule&.total_minutes || 0
  end

  def slots
    @slots ||= begin
      by_number = elective_surgeries.group_by(&:slot_number)
      (1..slot_count).map do |number|
        Slot.new(
          number: number,
          surgeries: by_number[number] || [],
          duration_minutes: slot_duration_minutes
        )
      end
    end
  end

  # Elective surgeries that have no slot to sit in: either no slot number yet,
  # or one pointing past the slots the day actually has.
  def unscheduled_surgeries
    @unscheduled_surgeries ||= elective_surgeries.reject { |surgery| (1..slot_count).cover?(surgery.slot_number) }
  end

  def used_slots
    slots.count { |slot| !slot.empty? }
  end

  def remaining_slots
    [ slot_count - used_slots, 0 ].max
  end

  def used_minutes
    slots.sum(&:used_minutes)
  end

  def over_capacity?
    unscheduled_surgeries.any?
  end

  def over_capacity_count
    unscheduled_surgeries.size
  end

  def overrunning_slots
    slots.select(&:overrun?)
  end

  def warnings
    messages = []

    if holiday? && elective_surgeries.any?
      messages << "#{holiday.name} is a holiday: no elective slots are available."
    elsif !configured? && elective_surgeries.any?
      messages << "No elective slots are configured for #{date.strftime('%A')}."
    end

    # On a holiday, or a weekday with no slot rule configured at all, the
    # message above already explains why nothing can be scheduled, so listing
    # the same surgeries as "not assigned to a slot" only adds noise.
    return messages unless configured?

    messages << unscheduled_warning if over_capacity?
    messages << overrun_warning if overrunning_slots.any?
    messages
  end

  private

    def unscheduled_warning
      if over_capacity_count == 1
        "1 elective surgery is not assigned to an available slot."
      else
        "#{over_capacity_count} elective surgeries are not assigned to an available slot."
      end
    end

    def overrun_warning
      if overrunning_slots.one?
        slot = overrunning_slots.first
        "Slot #{slot.number} is booked #{slot.overrun_minutes} min past its #{slot_duration_minutes} min limit."
      else
        numbers = overrunning_slots.map(&:number).join(", ")
        "Slots #{numbers} are booked past their #{slot_duration_minutes} min limit."
      end
    end
end

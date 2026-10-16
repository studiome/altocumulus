# Represents how a single day's elective surgery slots (see ElectiveSlotRule)
# are being used. A slot is a block of operating room time for the day, not a
# single operation: several surgeries are expected to share one slot, and a
# slot is only over its limit when the surgeries booked into it add up to more
# than the slot's duration. Surgeries are placed by their own slot_number, so
# an unassigned surgery waits outside the slots rather than filling one.
# Emergency surgeries are tracked separately and never affect slot usage or
# warnings.
#
# Besides the regular slots, a day can have special slots (特殊枠): lanes of a
# hybrid room / cath lab or a surgical robot (SpecialSlotRule). A case using
# one still sits in a regular slot and also takes one lane of each special
# resource it names. Lanes count elective cases only (no minutes), like the
# regular slots, so emergencies never take one; a closed holiday has none.
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

  # One special slot resource on the day: the lanes it has and the cases
  # using it.
  SpecialSlot = Struct.new(:resource, :capacity, :used) do
    def over?
      used > capacity
    end

    # "Cath Lab 1/2 lanes" (one text for the calendar and the PDF).
    def summary
      I18n.t("models.elective_slot_usage.special_slot", name: resource.name, used: used, capacity: capacity)
    end
  end

  attr_reader :date, :rule, :elective_surgeries, :emergency_surgeries, :holiday, :special_rules

  # Every positive weekly lane rule, with its resource (one query per resource
  # type); small and the same for all dates, so it is loaded once.
  def self.load_special_rules
    SpecialSlotRule.open.includes(:resource).to_a
  end

  # Builds one ElectiveSlotUsage per date in a single pass, issuing a fixed
  # number of queries regardless of how many dates are given (no N+1).
  # `includes` adds associations to preload on top of the always-loaded set
  # (e.g. what the ledger columns on screen read, see LedgerColumn.includes_for).
  def self.for_dates(dates, includes: [])
    dates = dates.to_a
    rules = ElectiveSlotRule.by_day_of_week
    holidays = Holiday.by_date(dates)
    special_rules = load_special_rules
    surgeries_by_date = Surgery.where(surgery_date: dates)
                                .includes(:patient, :department, :surgery_location, :surgical_device, :hospitalization,
                                          { surgery_procedure_selections: :surgery_procedure }, *includes)
                                .order(:slot_number, :start_time, :id)
                                .group_by(&:surgery_date)

    dates.index_with do |date|
      day_surgeries = surgeries_by_date[date] || []
      new(
        date: date,
        rule: rules[date.wday],
        elective_surgeries: day_surgeries.select(&:elective?),
        emergency_surgeries: day_surgeries.select(&:emergency?),
        holiday: holidays[date],
        special_rules: special_rules
      )
    end
  end

  def initialize(date:, rule:, elective_surgeries:, emergency_surgeries:, holiday: nil, special_rules: [])
    @special_rules = special_rules
    @date = date
    @rule = rule
    @elective_surgeries = elective_surgeries
    @emergency_surgeries = emergency_surgeries
    @holiday = holiday
  end

  # A Holiday row on this date only shuts down elective slots when it is an
  # actual closed day (holiday: true). A comment-only row (holiday: false)
  # must never affect slot usage.
  def holiday?
    holiday.present? && holiday.holiday?
  end

  # The rule to actually apply for elective slots. A holiday shuts down
  # elective slots for the day regardless of the weekday rule; a comment-only
  # day with a slot_count replaces the weekday rule (see
  # Holiday#effective_rule_for); emergency surgeries never consult this and
  # are never affected.
  def effective_rule
    return @effective_rule if defined?(@effective_rule)

    @effective_rule = holiday? ? nil : (holiday&.effective_rule_for(rule) || rule)
  end

  # True when a Holiday row's slot_count is what this day is using instead of
  # the weekday rule.
  def slot_override?
    !holiday? && holiday.present? && holiday.slot_override?
  end

  def slot_count_display
    effective_rule&.slot_count_display
  end

  def configured?
    effective_rule.present?
  end

  def slot_count
    effective_rule&.slot_count || 0
  end

  # The number of slots the day actually has. A fractional slot_count (e.g.
  # 2.5) still means 3 physical slots, the last one just shorter - always use
  # this for anything that counts or iterates slots, never slot_count itself
  # (a Range built from a fractional endpoint silently floors it in Ruby,
  # dropping the short last slot).
  def total_slots
    effective_rule&.total_slots || 0
  end

  def slot_duration_minutes
    effective_rule&.slot_duration_minutes
  end

  def capacity_minutes
    effective_rule&.total_minutes&.round || 0
  end

  def regular_surgeries
    @regular_surgeries ||= elective_surgeries.select(&:regular_slot?)
  end

  def simultaneous_surgeries
    @simultaneous_surgeries ||= elective_surgeries.select(&:simultaneous_slot?)
  end

  def backup_surgeries
    @backup_surgeries ||= elective_surgeries.select(&:backup_slot?)
  end

  def off_slot_surgeries
    @off_slot_surgeries ||= elective_surgeries.select(&:off_slot?)
  end

  def slots
    @slots ||= begin
      by_number = regular_surgeries.group_by(&:slot_number)
      durations = effective_rule&.slot_durations || []
      (1..total_slots).map do |number|
        Slot.new(
          number: number,
          surgeries: by_number[number] || [],
          duration_minutes: durations[number - 1]
        )
      end
    end
  end

  # Regular elective surgeries that have no slot to sit in: either no slot number yet,
  # or one pointing past the slots the day actually has. Surgeries booked into
  # other slot categories (simultaneous, backup, off_slot) are displayed outside
  # the regular slot limits and do not count as unscheduled.
  def unscheduled_surgeries
    @unscheduled_surgeries ||= regular_surgeries.reject { |surgery| (1..total_slots).cover?(surgery.slot_number) }
  end

  def used_slots
    slots.count { |slot| !slot.empty? }
  end

  def remaining_slots
    [ total_slots - used_slots, 0 ].max
  end

  def used_minutes
    slots.sum(&:used_minutes)
  end

  # Whether the day's booked minutes exceed what its slots hold: in total, or
  # because some single slot is overbooked even though the day as a whole fits.
  def minutes_over?
    used_minutes > capacity_minutes || overrunning_slots.any?
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

  # The day's special slot resources: every one with lanes that weekday or
  # with a case using it (a resource that has no lane rule at all is not
  # special and never listed), ordered locations first, then devices, each by
  # its master position. Uses the surgeries' foreign keys, so nothing is
  # loaded per case.
  def special_slots
    @special_slots ||= begin
      resources = special_rules.to_h { |special| [ [ special.resource_type, special.resource_id ], special.resource ] }
      lanes = holiday? ? {} : special_rules.select { |special| special.day_of_week == date.wday }.to_h { |special| [ [ special.resource_type, special.resource_id ], special.slot_count ] }
      used = Hash.new(0)
      elective_surgeries.each do |surgery|
        used[[ "SurgeryLocation", surgery.surgery_location_id ]] += 1 if surgery.surgery_location_id
        used[[ "SurgicalDevice", surgery.surgical_device_id ]] += 1 if surgery.surgical_device_id
      end

      keys = (lanes.keys + used.keys).uniq.select { |key| resources.key?(key) }
      keys.map { |key| SpecialSlot.new(resources[key], lanes.fetch(key, 0), used[key]) }
          .sort_by { |special| [ SpecialSlotRule::RESOURCE_TYPES.index(special.resource.class.name), special.resource.position, special.resource.name ] }
    end
  end

  def special_over?
    special_slots.any?(&:over?)
  end

  def warnings
    messages = []

    if holiday? && regular_surgeries.any?
      messages << I18n.t("models.elective_slot_usage.warnings.holiday", holiday_name: holiday.name)
    elsif !configured? && regular_surgeries.any?
      # I18n.l (not Date#strftime directly) so %A resolves through the
      # current locale's date.day_names rather than always English.
      messages << I18n.t("models.elective_slot_usage.warnings.not_configured", day: I18n.l(date, format: "%A"))
    end

    # On a holiday, or a weekday with no slot rule configured at all, the
    # message above already explains why no regular surgery can be scheduled,
    # so listing the same surgeries as "not assigned to a slot" only adds noise.
    if configured?
      messages << unscheduled_warning if over_capacity?
      messages << overrun_warning if overrunning_slots.any?
    end
    messages.concat(special_warnings)
  end

  private

    def special_warnings
      special_slots.select(&:over?).map do |special|
        I18n.t("models.elective_slot_usage.warnings.special_over", name: special.resource.name, used: special.used, capacity: special.capacity)
      end
    end

    def unscheduled_warning
      I18n.t("models.elective_slot_usage.warnings.unscheduled", count: over_capacity_count)
    end

    # A fractional slot_count can give slots different durations (the last
    # one shortened), so a single overrun slot always states its own limit,
    # and several overrunning slots only share one combined sentence when
    # their limits actually match.
    def overrun_warning
      if overrunning_slots.one?
        slot = overrunning_slots.first
        I18n.t("models.elective_slot_usage.warnings.overrun.single",
               number: slot.number, overrun: slot.overrun_minutes, limit: slot.duration_minutes)
      else
        durations = overrunning_slots.map(&:duration_minutes).uniq
        if durations.one?
          numbers = overrunning_slots.map(&:number).join(", ")
          I18n.t("models.elective_slot_usage.warnings.overrun.same_limit", numbers: numbers, limit: durations.first)
        else
          overrunning_slots.map { |slot|
            I18n.t("models.elective_slot_usage.warnings.overrun.item", number: slot.number, limit: slot.duration_minutes)
          }.join(" ")
        end
      end
    end
end

module ReservationsHelper
  # The error messages of one or more reservation error keys
  # ("hospitalization.purpose", "surgery.surgery_date", ...), as the small red
  # line shown under a field. Nil when there are none.
  def reservation_field_error(reservation, *keys)
    messages = keys.flat_map { |key| reservation.errors[key.to_sym] }.uniq
    return if messages.empty?

    tag.p(safe_join(messages, tag.br), id: reservation_error_id(keys.first), class: "text-error text-sm mt-1")
  end

  # aria attributes for a control whose error shows under it (see
  # reservation_field_error), to merge into the control's html options.
  def reservation_aria(reservation, *keys)
    return {} if keys.none? { |key| reservation.errors.key?(key.to_sym) }

    { aria: { invalid: true, describedby: reservation_error_id(keys.first) } }
  end

  def reservation_error_id(key)
    "reservation-error-#{key.to_s.tr('._', '--')}"
  end

  # A label for a Hospitalization attribute whose asterisk follows the site
  # config, including the fields required only for some purposes (the
  # purpose-fields controller keeps those in step with the purpose select).
  def hospitalization_label(form, attribute, text = nil)
    purposes = required_purposes_for(attribute)
    data = purposes ? { required_purposes: purposes, purpose_fields_target: "requiredLabel" } : {}
    form.label attribute, text || Hospitalization.human_attribute_name(attribute),
               class: required_label_class(Hospitalization, attribute, record: form.object), data: data
  end

  def surgery_label(form, attribute, text = nil)
    form.label attribute, text || Surgery.human_attribute_name(attribute), class: required_label_class(Surgery, attribute)
  end

  # Surgery locations as select options carrying whether they ask for a
  # performing department (the form shows that select only then).
  def surgery_location_options(selected_id)
    options = SurgeryLocation.choices_for(selected_id).map do |location|
      [ location.name, location.id, { data: { asks_performing_department: location.asks_performing_department? } } ]
    end
    options_for_select(options, selected_id)
  end

  # Slot usage of a day as the calendar words it: "2 / 3 slots (240 / 720 min)".
  def reservation_slot_summary(usage)
    safe_join([
      t("operations_calendar.day.slots_summary", used: usage.used_slots, total: usage.total_slots),
      t("operations_calendar.day.minutes_summary", used: usage.used_minutes, capacity: usage.capacity_minutes)
    ], " ")
  end

  # A team term's members line, or the reason there is none.
  def reservation_team_members_text(team, term)
    return t("reservations.team_members.pick_team") if team.nil?
    return t("reservations.team_members.no_term") if term.nil?

    term.members_display.presence || t("reservations.team_members.no_members")
  end
end

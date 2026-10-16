module ApplicationHelper
  # CSS class for the label of a field whose requiredness is chosen by the
  # site config (see ConfigurableRequiredFields): the asterisk comes from the
  # same source as the validation, so the two cannot disagree.
  #
  # Pass the form's record as `record:` for a field that is only required in
  # some situations (e.g. by hospitalization purpose); the mark then follows
  # that record as rendered.
  def required_label_class(model_class, attribute, record: nil)
    classes = %w[app-field-label]
    classes << "app-field-label-required" if model_class.required_attribute?(attribute, record)
    classes.join(" ")
  end

  # Options of a team select: the "team undecided" choice first, then the
  # active teams plus the record's current one. Pair with
  # `selected: record.team_choice` (see TeamAssignable).
  def team_select_options(record)
    [ [ t("teams.undecided"), TeamAssignable::UNDECIDED ] ] + Team.choices_for(record.team_id).map { |team| [ team.name, team.id ] }
  end

  # The users a form may offer for a "which person" field, ordered by name:
  # every active user, plus the one the record being edited already points at
  # (even if deactivated since), the way MasterRecord.choices_for does.
  def user_choices_for(current_id)
    User.active.or(User.where(id: current_id)).order(:name)
  end

  # Space-separated hospitalization purposes for which the site requires the
  # attribute without always requiring it, or nil. The purpose-fields
  # Stimulus controller reads it to keep a label's asterisk in step with the
  # purpose select as it changes.
  def required_purposes_for(attribute)
    return nil if Hospitalization.required_attribute?(attribute)

    purposes = Hospitalization::PURPOSE_KEYS.select { |purpose| Hospitalization.required_attribute?(attribute, purpose: purpose) }
    purposes.join(" ").presence
  end

  # The installation's own name (see AppSetting). Memoized because the layout
  # asks for it more than once per request.
  def app_title
    @app_title ||= AppSetting.title
  end

  # A date with its weekday, coloured for days off: Saturday blue, Sunday and
  # closed days (a Holiday row with holiday: true) red. `holidays` is the
  # Holiday.by_date hash a list page loads once for all its dates; single-date
  # callers can omit it and pay one lookup. A Holiday row with holiday: false
  # is only a day comment and never colours anything.
  def date_with_weekday(date, holidays: nil)
    holiday = holidays ? holidays[date] : Holiday.find_by(date: date)
    css_class =
      if date.sunday? || holiday&.holiday?
        "app-date-holiday"
      elsif date.saturday?
        "app-date-sat"
      end

    tag.span(l(date, format: :with_weekday), class: css_class)
  end
end

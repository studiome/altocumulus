# Backs the chemotherapy tab of the operations calendar: the examination tab's
# layout (grouping by scheduled procedure date or effective admission date,
# the same filters, day cell and counts) for the purposes that record a
# treatment protocol (Hospitalization::PROTOCOL_PURPOSE_KEYS). Those admissions
# are listed here instead of on the examination tab; the admission tab still
# lists them with every other purpose.
class ChemotherapyCalendar < ExaminationCalendar
  PURPOSES = Hospitalization::PROTOCOL_PURPOSE_KEYS

  def self.ledger
    :chemotherapy_calendar
  end

  def self.purpose_scope(scope)
    scope.where(purpose: PURPOSES)
  end

  def view_key
    "chemotherapy"
  end

  def new_reservation_purpose
    "chemotherapy"
  end

  def empty_message_key
    "no_chemotherapy"
  end
end

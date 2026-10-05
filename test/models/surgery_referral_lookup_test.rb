require "test_helper"

class SurgeryReferralLookupTest < ActiveSupport::TestCase
  test "returns the referral source of the hospitalization covering the surgery date" do
    date = Date.new(2031, 5, 10)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date - 1, discharge_date: date + 3,
                                    outcome: "recovered", referred_from: "City Clinic")
    surgery = create_surgery(patient, date)

    assert_equal "City Clinic", lookup_for(surgery).referred_from_for(surgery)
  end

  test "also matches a hospitalization by its scheduled surgery date" do
    date = Date.new(2031, 5, 10)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date - 5, scheduled_surgery_date: date,
                                    admission_date: date + 1, referred_from: "Moved Clinic")
    surgery = create_surgery(patient, date)

    assert_equal "Moved Clinic", lookup_for(surgery).referred_from_for(surgery)
  end

  test "ignores hospitalizations that do not cover the date, are discarded or have no referral" do
    date = Date.new(2031, 5, 10)
    outside = new_patient
    create_hospitalization(outside, scheduled_admission_date: date + 10, referred_from: "Later Clinic")
    discarded = new_patient
    create_hospitalization(discarded, scheduled_admission_date: date - 1, referred_from: "Gone").discard!
    blank = new_patient
    create_hospitalization(blank, scheduled_admission_date: date - 1)

    surgeries = [ outside, discarded, blank ].map { |patient| create_surgery(patient, date) }
    lookup = lookup_for(*surgeries)

    surgeries.each { |surgery| assert_nil lookup.referred_from_for(surgery) }
  end

  test "returns the first matching hospitalization's referral source" do
    date = Date.new(2031, 5, 10)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date - 3, discharge_date: date - 1,
                                    outcome: "recovered", referred_from: "Earlier Clinic")
    create_hospitalization(patient, scheduled_admission_date: date, referred_from: "Current Clinic")
    surgery = create_surgery(patient, date)

    assert_equal "Current Clinic", lookup_for(surgery).referred_from_for(surgery)
  end

  test "handles an empty set of dates" do
    assert_nothing_raised { SurgeryReferralLookup.new(patient_ids: [], dates: []) }
  end

  test "handles a set of dates containing nil without raising" do
    assert_nothing_raised { SurgeryReferralLookup.new(patient_ids: [], dates: [ Date.today, nil ]) }
  end

  test "returns nil for an undated surgery" do
    date = Date.new(2031, 5, 10)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date, referred_from: "City Clinic")
    surgery = Surgery.create!(
      patient: patient, surgery_date: nil, surgery_date_status: "undecided", anesthesia_method: "General",
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    lookup = SurgeryReferralLookup.new(patient_ids: [ patient.id ], dates: [ date ])
    assert_nil lookup.referred_from_for(surgery)
  end

  test "returns nil for an undated surgery even when hospitalization has a scheduled surgery date" do
    date = Date.new(2031, 5, 10)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date, scheduled_surgery_date: date, referred_from: "City Clinic")
    surgery = Surgery.create!(
      patient: patient, surgery_date: nil, surgery_date_status: "undecided", anesthesia_method: "General",
      surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
    )

    lookup = SurgeryReferralLookup.new(patient_ids: [ patient.id ], dates: [ date ])
    assert_nil lookup.referred_from_for(surgery)
  end

  private

    def lookup_for(*surgeries)
      SurgeryReferralLookup.new(patient_ids: surgeries.map(&:patient_id), dates: surgeries.map(&:surgery_date))
    end

    def new_patient
      @patient_sequence = (@patient_sequence || 0) + 1
      Patient.create!(name: "Lookup Test Patient #{@patient_sequence}", hospital_id: "LKP#{@patient_sequence}",
                      date_of_birth: Date.new(1980, 1, 1))
    end

    def create_surgery(patient, date)
      Surgery.create!(
        patient: patient, surgery_date: date, anesthesia_method: "General",
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
      )
    end

    def create_hospitalization(patient, **attrs)
      Hospitalization.create!(
        { patient: patient, reason: "Lookup test reservation",
          hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ] }.merge(attrs)
      )
    end
end

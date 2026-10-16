require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  setup do
    # A patient with no hospitalizations of their own, so the overlap rule
    # never interferes.
    @patient = Patient.create!(hospital_id: "H900", name: "Reserve Me", date_of_birth: "1970-02-02")
    @user = users(:member)
    Current.user = @user
  end

  teardown { Current.reset }

  def surgery_params(overrides = {})
    {
      surgery_date: "2026-11-10", surgery_date_status: "scheduled", anesthesia_method: "General",
      scheduling_type: "elective", slot_category: "regular", duration_hours: "2"
    }.merge(overrides)
  end

  def params_for(purpose: "surgery", hospitalization: {}, surgery: {}, diagnoses: nil, procedures: nil)
    {
      hospitalization: {
        patient_id: @patient.id, purpose: purpose, scheduled_admission_date: "2026-11-09",
        reservation_doctor_id: @user.id
      }.merge(hospitalization),
      surgery: surgery_params(surgery),
      diagnoses: diagnoses || { "1" => { diagnosis_id: diagnoses(:appendicitis).id, laterality: "right" } },
      procedures: procedures || { "1" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" } }
    }
  end

  def build(**options)
    reservation = Reservation.new
    reservation.assign(params_for(**options))
    reservation
  end

  test "saves a hospitalization and its surgery together, linked" do
    reservation = build

    assert_difference [ "Hospitalization.count", "Surgery.count" ], 1 do
      assert reservation.save, reservation.errors.full_messages.to_sentence
    end

    hospitalization = reservation.hospitalization
    surgery = reservation.surgery
    assert_equal hospitalization, surgery.reload.hospitalization
    assert_equal @patient, surgery.patient
    assert_equal Date.new(2026, 11, 10), hospitalization.reload.scheduled_surgery_date
    assert_equal @user, hospitalization.created_by
    assert_equal [ surgery_procedures(:appendectomy) ], surgery.selected_surgery_procedures.to_a
    assert_equal [ diagnoses(:appendicitis) ], hospitalization.diagnoses.to_a
  end

  test "new reservations are stamped with today's submission date" do
    reservation = build
    reservation.save!
    assert_equal Date.current, reservation.hospitalization.submitted_on
  end

  test "rolls back the hospitalization when the surgery is invalid" do
    reservation = build(surgery: { anesthesia_method: "" })

    assert_no_difference [ "Hospitalization.count", "Surgery.count" ] do
      assert_not reservation.save
    end
    assert reservation.errors.key?(:"surgery.anesthesia_method")
  end

  test "does not save the surgery when the hospitalization is invalid" do
    reservation = build(hospitalization: { scheduled_admission_date: "" })

    assert_no_difference [ "Hospitalization.count", "Surgery.count" ] do
      assert_not reservation.save
    end
    assert reservation.errors.key?(:"hospitalization.admission_date")
  end

  test "rolls back everything when saving the surgery fails after the hospitalization is stored" do
    reservation = build
    reservation.surgery.define_singleton_method(:save!) { |*| raise ActiveRecord::RecordInvalid.new(self) }

    assert_no_difference [ "Hospitalization.count", "PatientDiagnosis.count" ] do
      assert_not reservation.save
    end
  end

  test "a purpose other than surgery creates no surgery and ignores surgery attributes" do
    reservation = build(purpose: "examination", surgery: { anesthesia_method: "" })

    assert_difference "Hospitalization.count", 1 do
      assert_no_difference "Surgery.count" do
        assert reservation.save, reservation.errors.full_messages.to_sentence
      end
    end
    assert_nil reservation.surgery
  end

  test "merges field errors from both records under prefixed keys" do
    reservation = build(hospitalization: { scheduled_admission_date: "" },
                        surgery: { anesthesia_method: "" }, diagnoses: {}, procedures: {})

    assert_not reservation.valid?
    assert reservation.errors.key?(:"hospitalization.admission_date")
    assert reservation.errors.key?(:"hospitalization.hospitalization_diagnoses")
    assert reservation.errors.key?(:"surgery.anesthesia_method")
    assert reservation.errors.key?(:"surgery.surgery_procedure_selections")
    assert_includes reservation.errors.full_messages.to_sentence, "Anesthesia method"
  end

  test "configured required fields apply, including purpose-conditional ones" do
    config = { "required_fields" => { "hospitalization" => [ "referred_from" ], "surgery" => [ "operator_name" ],
                                      "hospitalization_by_purpose" => { "examination" => [ "procedure_name" ] } } }
    with_site_config(config) do
      reservation = build
      assert_not reservation.valid?
      assert reservation.errors.key?(:"hospitalization.referred_from")
      assert reservation.errors.key?(:"surgery.operator_name")
      assert_not reservation.errors.key?(:"hospitalization.procedure_name")

      exam = build(purpose: "examination")
      assert_not exam.valid?
      assert exam.errors.key?(:"hospitalization.procedure_name")
      assert exam.errors.key?(:"hospitalization.referred_from")
      assert_not exam.errors.key?(:"surgery.operator_name")
    end
  end

  test "reuses the patient's existing diagnosis record for the same diagnosis and laterality" do
    patient = patients(:two)
    existing = patient_diagnoses(:pneumonia) # bilateral pneumonia
    reservation = Reservation.new
    reservation.assign(params_for(
      hospitalization: { patient_id: patient.id, scheduled_admission_date: "2027-03-01" },
      surgery: { surgery_date: "2027-03-02" },
      diagnoses: { "1" => { diagnosis_id: diagnoses(:pneumonia).id, laterality: "bilateral" } }
    ))

    assert_no_difference "PatientDiagnosis.count" do
      assert reservation.save, reservation.errors.full_messages.to_sentence
    end
    assert_equal [ existing ], reservation.surgery.reload.patient_diagnoses.to_a
  end

  test "creates a patient diagnosis when none matches the diagnosis and laterality" do
    patient = patients(:two)
    reservation = Reservation.new
    reservation.assign(params_for(
      hospitalization: { patient_id: patient.id, scheduled_admission_date: "2027-03-01" },
      surgery: { surgery_date: "2027-03-02" },
      diagnoses: { "1" => { diagnosis_id: diagnoses(:pneumonia).id, laterality: "left" } }
    ))

    assert_difference "PatientDiagnosis.count", 1 do
      assert reservation.save, reservation.errors.full_messages.to_sentence
    end
    created = reservation.surgery.reload.patient_diagnoses.first
    assert_equal "left", created.laterality
    assert_equal diagnoses(:pneumonia), created.diagnosis
    assert_equal Date.current, created.diagnosed_on
  end

  test "a created patient diagnosis is dated on the submission date when given" do
    reservation = build(hospitalization: { submitted_on: "2026-11-01" })
    reservation.save!
    assert_equal Date.new(2026, 11, 1), reservation.surgery.patient_diagnoses.first.diagnosed_on
  end

  test "no patient diagnosis is created for a purpose other than surgery" do
    reservation = build(purpose: "examination")
    assert_no_difference "PatientDiagnosis.count" do
      reservation.save!
    end
  end

  test "the surgery's team defaults from the hospitalization's team" do
    team = teams(:blue)
    with_site_config("features" => { "teams" => true }) do
      reservation = build(hospitalization: { team_id: team.id })
      reservation.save!
      assert_equal team, reservation.surgery.reload.team
    end
  end

  test "for_hospitalization loads the first linked surgery by date and updates both" do
    reservation = build
    reservation.save!
    hospitalization = reservation.hospitalization
    later = Surgery.create!(patient: @patient, hospitalization: hospitalization, surgery_date: "2026-11-20",
                            anesthesia_method: "Spinal", surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ])

    loaded = Reservation.for_hospitalization(Hospitalization.find(hospitalization.id))
    assert_equal reservation.surgery.id, loaded.surgery.id
    assert_not_equal later.id, loaded.surgery.id
    assert_equal [ "right" ], loaded.diagnosis_rows.map(&:laterality)

    assert loaded.update(
      hospitalization: { planned_days: "4" },
      surgery: { duration_hours: "3.5" },
      diagnoses: loaded.diagnosis_rows.each_with_index.to_h { |row, i| [ i.to_s, { id: row.id, diagnosis_id: row.diagnosis_id, laterality: row.laterality } ] },
      procedures: loaded.procedure_rows.each_with_index.to_h { |row, i| [ i.to_s, { id: row.id, surgery_procedure_id: row.surgery_procedure_id, laterality: row.laterality } ] }
    ), loaded.errors.full_messages.to_sentence
    assert_equal 4, hospitalization.reload.planned_days
    assert_in_delta 3.5, loaded.surgery.reload.duration_hours
  end

  test "editing keeps related diagnoses that are not part of the reservation's diagnoses" do
    reservation = build
    reservation.save!
    extra = PatientDiagnosis.create!(patient: @patient, diagnosis: diagnoses(:hypertension), diagnosed_on: Date.current)
    reservation.surgery.patient_diagnoses << extra

    loaded = Reservation.for_hospitalization(Hospitalization.find(reservation.hospitalization.id))
    assert loaded.update(hospitalization: { planned_days: "2" })
    assert_includes loaded.surgery.reload.patient_diagnoses, extra
  end

  test "changing a diagnosis row's laterality relinks the surgery to the matching patient diagnosis" do
    reservation = build
    reservation.save!
    loaded = Reservation.for_hospitalization(Hospitalization.find(reservation.hospitalization.id))
    row = loaded.diagnosis_rows.first

    assert loaded.update(diagnoses: { "1" => { id: row.id, diagnosis_id: row.diagnosis_id, laterality: "left" } })
    assert_equal [ "left" ], loaded.surgery.reload.patient_diagnoses.map(&:laterality)
  end

  test "switching an edited reservation away from surgery is refused while its surgery exists" do
    reservation = build
    reservation.save!
    loaded = Reservation.for_hospitalization(Hospitalization.find(reservation.hospitalization.id))

    assert_no_difference "Surgery.count" do
      assert_not loaded.update(hospitalization: { purpose: "examination" })
    end
    assert loaded.errors.key?(:"hospitalization.purpose")
    assert_equal "surgery", reservation.hospitalization.reload.purpose
  end

  test "switching an edited non-surgery reservation to surgery creates the surgery" do
    exam = build(purpose: "examination")
    exam.save!
    loaded = Reservation.for_hospitalization(Hospitalization.find(exam.hospitalization.id))

    assert_difference "Surgery.count", 1 do
      assert loaded.update(
        hospitalization: { purpose: "surgery" }, surgery: surgery_params,
        procedures: { "1" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "none" } }
      ), loaded.errors.full_messages.to_sentence
    end
    assert_equal loaded.hospitalization, loaded.surgery.hospitalization
  end

  test "clears the performing department unless the location asks for one" do
    cath = surgery_locations(:cath_lab)
    cath.update!(asks_performing_department: true)
    gyn = departments(:gynecology)

    asked = build(surgery: { slot_category: "off_slot", surgery_location_id: cath.id, performing_department_id: gyn.id })
    asked.save!
    assert_equal gyn, asked.surgery.reload.performing_department

    other_patient = Patient.create!(hospital_id: "H901", name: "Other", date_of_birth: "1971-01-01")
    params = params_for(hospitalization: { patient_id: other_patient.id },
                        surgery: { slot_category: "off_slot", surgery_location_id: surgery_locations(:hybrid_room).id, performing_department_id: gyn.id })
    unasked = Reservation.new
    unasked.assign(params)
    unasked.save!
    assert_nil unasked.surgery.reload.performing_department
  end

  test "defaults for a new reservation come from the prefill" do
    reservation = Reservation.build_new(user: @user, surgery_date: "2026-12-01", scheduled_admission_date: "2026-11-30",
                                        purpose: "surgery", patient_id: @patient.id)

    assert_equal "surgery", reservation.hospitalization.purpose
    assert_equal @patient, reservation.hospitalization.patient
    assert_equal @user, reservation.hospitalization.reservation_doctor
    assert_equal Date.new(2026, 11, 30), reservation.hospitalization.scheduled_admission_date
    assert_equal Date.new(2026, 12, 1), reservation.surgery.surgery_date
    assert_equal 1, reservation.diagnosis_rows_for_form.size
    assert_equal 1, reservation.procedure_rows_for_form.size
  end

  test "build_new ignores junk prefill values" do
    reservation = Reservation.build_new(user: @user, surgery_date: [ "x" ], scheduled_admission_date: "nope",
                                        purpose: "bogus", patient_id: "9999999")

    assert_nil reservation.hospitalization.scheduled_admission_date
    assert_nil reservation.surgery.surgery_date
    assert_nil reservation.hospitalization.patient
    assert_equal "surgery", reservation.hospitalization.purpose
  end

  test "swapping two existing diagnosis rows is reported instead of raising" do
    reservation = build(diagnoses: {
      "1" => { diagnosis_id: diagnoses(:appendicitis).id, laterality: "none" },
      "2" => { diagnosis_id: diagnoses(:pneumonia).id, laterality: "none" }
    })
    reservation.save!

    loaded = Reservation.for_hospitalization(Hospitalization.find(reservation.hospitalization.id))
    a, b = loaded.diagnosis_rows
    swapped = { "1" => { id: a.id, diagnosis_id: b.diagnosis_id, laterality: "none" },
                "2" => { id: b.id, diagnosis_id: a.diagnosis_id, laterality: "none" } }

    assert_not loaded.update(diagnoses: swapped)
    assert loaded.errors.key?(:"hospitalization.hospitalization_diagnoses")
  end
end

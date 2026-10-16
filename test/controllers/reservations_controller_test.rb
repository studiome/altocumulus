require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  # Far enough ahead to fall outside the calendar's default range, so the
  # redirect carries a `start`.
  SURGERY_DATE = Date.current + 100
  ADMISSION_DATE = SURGERY_DATE - 1
  setup do
    @user = users(:member)
    sign_out
    sign_in_as(@user)
    @patient = Patient.create!(hospital_id: "H800", name: "Form Patient", name_kana: "フォーム", date_of_birth: "1975-05-05", sex: "female")
  end

  def valid_params(overrides = {})
    {
      reservation: {
        hospitalization: { patient_id: @patient.id, purpose: "surgery", scheduled_admission_date: "2026-11-09",
                           reservation_doctor_id: @user.id, transfer_status: "none", emergency_admission: "false" },
        surgery: { surgery_date: SURGERY_DATE.iso8601, surgery_date_status: "scheduled", scheduling_type: "elective",
                   slot_category: "regular", anesthesia_method: "General", duration_hours: "2" },
        diagnoses: { "1" => { diagnosis_id: diagnoses(:appendicitis).id, laterality: "right" } },
        procedures: { "1" => { surgery_procedure_id: surgery_procedures(:appendectomy).id, laterality: "right" } }
      }
    }.deep_merge(overrides)
  end

  test "requires sign in" do
    sign_out
    get new_reservation_url
    assert_redirected_to login_url
  end

  test "any signed-in user may open the form" do
    get new_reservation_url
    assert_response :success
    assert_select "form[action=?]", reservations_path
    assert_select "section#reservation-hospitalization-heading, h2#reservation-hospitalization-heading"
  end

  test "new is prefilled from the query string" do
    get new_reservation_url, params: { surgery_date: "2026-12-01", scheduled_admission_date: "2026-11-30", purpose: "surgery", patient_id: @patient.id }
    assert_response :success

    assert_select "input[name='reservation[surgery][surgery_date]'][value='2026-12-01']"
    assert_select "input[name='reservation[hospitalization][scheduled_admission_date]'][value='2026-11-30']"
    assert_select "input[name='reservation[hospitalization][patient_id]'][value='#{@patient.id}']"
    assert_select "select[name='reservation[hospitalization][purpose]'] option[selected][value=surgery]"
    assert_select "select[name='reservation[hospitalization][reservation_doctor_id]'] option[selected][value='#{@user.id}']"
    assert_select "[data-testid=entered-by]", text: /#{@user.name}/
    assert_select "[data-testid=patient-card]", text: /H800/
  end

  test "new ignores a non-surgery purpose prefill for the surgery section but shows procedure fields" do
    get new_reservation_url, params: { purpose: "examination" }
    assert_select "select[name='reservation[hospitalization][purpose]'] option[selected][value=examination]"
    assert_select "section[data-purpose-fields-target=surgerySection].hidden"
    assert_select "section[data-purpose-fields-target=procedureSection]:not(.hidden)"
  end

  test "the surgery section is shown for the surgery purpose and the examination one is hidden" do
    get new_reservation_url, params: { purpose: "surgery" }
    assert_select "section[data-purpose-fields-target=surgerySection]:not(.hidden)"
    assert_select "section[data-purpose-fields-target=procedureSection].hidden"
  end

  test "create saves both records and redirects to the calendar highlighting the surgery date" do
    assert_difference [ "Hospitalization.count", "Surgery.count" ], 1 do
      post reservations_url, params: valid_params
    end

    surgery = Surgery.order(:id).last
    assert_equal surgery.hospitalization, Hospitalization.order(:id).last
    assert_equal @user, surgery.hospitalization.created_by
    assert_redirected_to operations_calendar_path(start: (SURGERY_DATE - 7).iso8601, highlight: SURGERY_DATE.iso8601, anchor: "day-#{SURGERY_DATE.iso8601}")
    assert_equal surgery_path(surgery), flash[:notice_link]["path"]
  end

  test "create for a date inside the default calendar range omits the start" do
    date = Date.current + 3
    post reservations_url, params: valid_params(reservation: { surgery: { surgery_date: date.iso8601 },
                                                                 hospitalization: { scheduled_admission_date: (date - 1).iso8601 } })
    assert_redirected_to operations_calendar_path(highlight: date.iso8601, anchor: "day-#{date.iso8601}")
  end

  test "create for an examination makes no surgery and goes to the hospitalization" do
    params = valid_params(reservation: { hospitalization: { purpose: "examination" } })
    params[:reservation].delete(:surgery)
    params[:reservation].delete(:procedures)

    assert_difference "Hospitalization.count", 1 do
      assert_no_difference "Surgery.count" do
        post reservations_url, params: params
      end
    end
    assert_redirected_to hospitalization_path(Hospitalization.order(:id).last)
  end

  test "create for an undated surgery goes to the hospitalization" do
    post reservations_url, params: valid_params(reservation: { surgery: { surgery_date: "", surgery_date_status: "undecided" } })
    assert_redirected_to hospitalization_path(Hospitalization.order(:id).last)
    assert_nil Surgery.order(:id).last.surgery_date
  end

  test "create failure re-renders with field errors, a summary and the entered values" do
    params = valid_params(reservation: { surgery: { anesthesia_method: "" }, hospitalization: { scheduled_admission_date: "" } })

    assert_no_difference [ "Hospitalization.count", "Surgery.count" ] do
      post reservations_url, params: params
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] h2", text: /errors prohibited/
    assert_select "[role=alert] li", text: /Anesthesia method/
    assert_select "p.text-error", text: /can't be blank/
    assert_select "#reservation-error-surgery-anesthesia_method, [id='reservation-error-surgery-anesthesia-method']"
    assert_select "input[name='reservation[surgery][surgery_date]'][value='#{SURGERY_DATE.iso8601}']"
    assert_select "input[name='reservation[hospitalization][patient_id]'][value='#{@patient.id}']"
    assert_select "input[name='reservation[diagnoses][0][diagnosis_id]'][value='#{diagnoses(:appendicitis).id}']"
  end

  test "required fields from the site config are enforced and rendered with an asterisk" do
    config = { "required_fields" => { "surgery" => [ "operator_name" ], "hospitalization_by_purpose" => { "examination" => [ "procedure_name" ] } } }
    with_site_config(config) do
      post reservations_url, params: valid_params
      assert_response :unprocessable_entity
      assert_select "p.text-error", text: /can't be blank/
      assert_select "label.app-field-label-required[for='reservation_surgery_operator_name']"
      assert_select "label[for='reservation_hospitalization_procedure_name'][data-required-purposes='examination']"
    end
  end

  test "edit loads the hospitalization and its surgery" do
    post reservations_url, params: valid_params
    hospitalization = Hospitalization.order(:id).last

    get edit_reservation_url(hospitalization)
    assert_response :success
    assert_select "form[action=?]", reservation_path(hospitalization)
    assert_select "input[name='_method'][value=patch]"
    assert_select "input[name='reservation[surgery][surgery_date]'][value='#{SURGERY_DATE.iso8601}']"
    assert_select "input[name='reservation[diagnoses][0][id]']"
    assert_select "select[name='reservation[diagnoses][0][laterality]'] option[selected][value=right]"
    assert_select "input[name='reservation[procedures][0][id]']"
  end

  test "update changes both records and redirects to the calendar" do
    post reservations_url, params: valid_params
    hospitalization = Hospitalization.order(:id).last
    surgery = hospitalization.surgeries.first
    row_id = hospitalization.hospitalization_diagnoses.first.id
    selection_id = surgery.surgery_procedure_selections.first.id

    patch reservation_url(hospitalization), params: valid_params(reservation: {
      hospitalization: { planned_days: "6" }, surgery: { duration_hours: "4" },
      diagnoses: { "1" => { id: row_id } }, procedures: { "1" => { id: selection_id } }
    })

    assert_response :see_other
    assert_redirected_to operations_calendar_path(start: (SURGERY_DATE - 7).iso8601, highlight: SURGERY_DATE.iso8601, anchor: "day-#{SURGERY_DATE.iso8601}")
    assert_equal 6, hospitalization.reload.planned_days
    assert_in_delta 4.0, surgery.reload.duration_hours
  end

  test "update failure re-renders the edit form" do
    post reservations_url, params: valid_params
    hospitalization = Hospitalization.order(:id).last
    row_id = hospitalization.hospitalization_diagnoses.first.id

    patch reservation_url(hospitalization), params: valid_params(reservation: {
      hospitalization: { purpose: "examination" }, diagnoses: { "1" => { id: row_id } }
    })

    assert_response :unprocessable_entity
    assert_select "p.text-error", text: /Delete the surgery/
    assert_select "form[action=?]", reservation_path(hospitalization)
  end

  test "a deleted hospitalization cannot be edited" do
    post reservations_url, params: valid_params
    hospitalization = Hospitalization.order(:id).last
    hospitalization.discard!

    get edit_reservation_url(hospitalization)
    assert_response :not_found
  end

  test "the surgery section shows the performing department only for flagged locations" do
    surgery_locations(:cath_lab).update!(asks_performing_department: true)

    get new_reservation_url, params: { purpose: "surgery" }

    assert_select "select[name='reservation[surgery][surgery_location_id]'] option[value='#{surgery_locations(:cath_lab).id}'][data-asks-performing-department=true]"
    assert_select "select[name='reservation[surgery][surgery_location_id]'] option[value='#{surgery_locations(:hybrid_room).id}'][data-asks-performing-department=false]"
    assert_select "[data-reservation-surgery-target=performingSection].hidden"
  end

  test "the team select and member preview appear only when teams are enabled" do
    get new_reservation_url
    assert_select "select[name='reservation[hospitalization][team_id]']", count: 0

    with_site_config("features" => { "teams" => true }) do
      get new_reservation_url
      assert_select "select[name='reservation[hospitalization][team_id]']"
      assert_select "turbo-frame#reservation_team_members"
    end
  end

  test "every control of the form has an accessible name" do
    get new_reservation_url, params: { purpose: "surgery" }

    css_select("form input:not([type=hidden]):not([type=submit]), form select, form textarea").each do |control|
      next if control.ancestors("template").any?

      id = control["id"]
      labelled = control["aria-label"].present? ||
                 (id.present? && css_select("label[for='#{id}']").any?) ||
                 control.ancestors("label").any?
      assert labelled, "#{control.name} #{control['name']} has no label"
    end
  end

  # ---- live frames --------------------------------------------------------

  test "patient_card renders the confirmation card with the last two hospitalizations" do
    3.times do |i|
      Hospitalization.create!(patient: @patient, scheduled_admission_date: "2026-0#{i + 1}-10", discharge_date: "2026-0#{i + 1}-12",
                              outcome: "recovered", purpose: "examination", procedure_name: "Scope #{i}",
                              hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ])
    end

    get patient_card_reservations_url(patient_id: @patient.id)

    assert_response :success
    assert_select "turbo-frame#reservation_patient_card" do
      assert_select ".font-mono", text: "H800"
      assert_select "*", text: /Form Patient/
      assert_select "*", text: /フォーム/
      assert_select "li", 2
      assert_select "li", text: /Scope 2/
      assert_select "li", text: /Scope 1/
    end
    assert_match "Check that the ID and name match the paper chart", response.body
  end

  test "patient_card without a patient asks to pick one" do
    get patient_card_reservations_url(patient_id: "")
    assert_select "turbo-frame#reservation_patient_card [data-testid=patient-card-empty]"
  end

  test "admission_count reports the day's count against the threshold" do
    Hospitalization.create!(patient: @patient, scheduled_admission_date: "2026-11-09", purpose: "examination",
                            hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ])

    get admission_count_reservations_url(date: "2026-11-09")

    assert_select "turbo-frame#reservation_admission_count", text: /1/
    assert_select ".badge-warning", count: 0
    get admission_count_reservations_url(date: "junk")
    assert_select "turbo-frame#reservation_admission_count", text: /Enter a date/
  end

  test "admission_count marks a congested day" do
    patients = 3.times.map { |i| Patient.create!(hospital_id: "HC#{i}", name: "C#{i}", date_of_birth: "1980-01-01") }
    patients.each do |patient|
      Hospitalization.create!(patient: patient, scheduled_admission_date: "2026-11-09", purpose: "examination",
                              hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ])
    end
    original = Rails.application.config.x.admission_warning_threshold
    begin
      Rails.application.config.x.admission_warning_threshold = 2
      get admission_count_reservations_url(date: "2026-11-09")
    ensure
      Rails.application.config.x.admission_warning_threshold = original
    end
    assert_select ".badge-warning"
  end

  test "admission_calendar renders the month with counts, the selected day and navigation" do
    Hospitalization.create!(patient: @patient, scheduled_admission_date: "2026-11-09", purpose: "examination",
                            hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ])

    get admission_calendar_reservations_url(month: "2026-11", selected: "2026-11-09")

    assert_select "turbo-frame#reservation_admission_calendar" do
      assert_select "h3", text: /11\/2026/
      assert_select ".ring-primary", 1
      assert_select "a[href=?]", admission_calendar_reservations_path(month: "2026-10", selected: "2026-11-09")
      assert_select "a[href=?]", admission_calendar_reservations_path(month: "2026-12", selected: "2026-11-09")
    end
  end

  test "slot_summary shows the used slots and minutes of the date" do
    get slot_summary_reservations_url(date: "2026-03-03")

    assert_select "turbo-frame#reservation_slot_summary", text: /2 \/ 3 slots/
    assert_select "turbo-frame#reservation_slot_summary", text: /min/
  end

  test "slot_summary honors a holiday slot override" do
    Holiday.create!(date: "2026-11-10", name: "Special day", holiday: false, slot_count: 1, slot_duration_minutes: 60)
    get slot_summary_reservations_url(date: "2026-11-10")
    assert_select "turbo-frame#reservation_slot_summary", text: /0 \/ 1 slots/
    assert_select ".badge-info"
  end

  test "team_members shows the members of the term covering the date" do
    with_site_config("features" => { "teams" => true }) do
      get team_members_reservations_url(team_id: teams(:blue).id, date: "2026-10-15")
      assert_select "turbo-frame#reservation_team_members", text: /Alpha/

      get team_members_reservations_url(team_id: teams(:blue).id, date: "2020-01-01")
      assert_select "turbo-frame#reservation_team_members", text: /No team term/

      get team_members_reservations_url(team_id: "", date: "2026-10-15")
      assert_select "turbo-frame#reservation_team_members", text: /Pick a team/
    end
  end

  test "team_members is not found while the teams feature is off" do
    get team_members_reservations_url(team_id: teams(:blue).id, date: "2026-10-15")
    assert_response :not_found
  end

  test "the side panel lists only published announcements" do
    get new_reservation_url
    assert_select "aside", text: /Winter schedule notice/
    assert_select "aside", text: /Draft: new ward opening/, count: 0
  end

  test "the new form does not run queries per announcement or per calendar day" do
    get new_reservation_url # warm up
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get new_reservation_url }
    assert_equal 1, queries.count { |sql| sql.include?("announcements") }
    assert_equal 1, queries.count { |sql| sql.include?("COALESCE(hospitalizations.admission_date") }
  end

  test "the show pages link to the reservation form" do
    post reservations_url, params: valid_params
    hospitalization = Hospitalization.order(:id).last
    surgery = hospitalization.surgeries.first

    get hospitalization_url(hospitalization)
    assert_select "a[href=?]", edit_reservation_path(hospitalization), text: I18n.t("reservations.links.edit_in_reservation_form")
    get surgery_url(surgery)
    assert_select "a[href=?]", edit_reservation_path(hospitalization), text: I18n.t("reservations.links.edit_in_reservation_form")
    get surgery_url(surgeries(:one))
    assert_select "a[href^='/reservations/']", count: 0
  end
end

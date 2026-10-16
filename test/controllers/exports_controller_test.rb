require "test_helper"
require "csv"

class ExportsControllerTest < ActionDispatch::IntegrationTest
  RANGE = { start: "2026-03-01", days: 3 }.freeze

  def rows(response_body = response.body)
    CSV.parse(response_body.delete_prefix("﻿"), row_sep: "\r\n")
  end

  def count_queries
    count = 0
    counter = ->(_n, _s, _f, _i, payload) { count += 1 unless payload[:cached] || payload[:name] == "SCHEMA" }
    ActiveRecord::Base.lease_connection.materialize_transactions
    ActiveRecord::Base.uncached { ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield } }
    count
  end

  test "an admin downloads the surgery list of the range" do
    get export_url(:surgery_list), params: RANGE.merge(view: "surgery")
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_match(/attachment; filename="surgery_list_2026-03-01_2026-03-03\.csv"/, response.headers["Content-Disposition"])
    assert response.body.start_with?("﻿")
    assert_not_includes response.body.delete("\r"), "\r"
    table = rows
    assert_includes table.first, "Surgery Date"
    date_column = table.first.index("Surgery Date")
    assert_equal %w[2026-03-01 2026-03-01 2026-03-02 2026-03-03 2026-03-03 2026-03-03 2026-03-03],
                 table.drop(1).map { |row| row[date_column] }
  end

  test "a data manager may export, a plain member may not" do
    sign_in_as(users(:data_manager))
    get export_url(:surgery_list), params: RANGE.merge(view: "surgery")
    assert_response :success

    sign_in_as(users(:member))
    assert_no_difference "AccessLog.count" do
      get export_url(:surgery_list), params: RANGE.merge(view: "surgery")
    end
    assert_redirected_to root_path
    assert_not_equal "text/csv", response.media_type
  end

  test "signed-out visitors are sent to the login page" do
    sign_out
    get export_url(:surgery_list), params: RANGE.merge(view: "surgery")
    assert_redirected_to login_path
  end

  test "an unknown export or a view that does not fit its subject is not found" do
    get export_url(:nope), params: RANGE.merge(view: "surgery")
    assert_response :not_found
    get export_url(:surgery_list), params: RANGE.merge(view: "examination")
    assert_response :not_found
    get export_url(:admission_list), params: RANGE.merge(view: "surgery")
    assert_response :not_found
    get export_url(:surgery_list), params: RANGE
    assert_response :not_found
  end

  test "a bad range goes back to the calendar" do
    get export_url(:surgery_list), params: { view: "surgery", start: "garbage" }
    assert_redirected_to operations_calendar_path
  end

  test "only the configured fields are exported, in order" do
    config = { "exports" => { "short" => { "subject" => "surgery", "fields" => %w[hospital_id surgery_date], "label" => "Short" } } }
    with_site_config(config) do
      get export_url(:short), params: RANGE.merge(view: "surgery")
      assert_equal [ "Patient ID", "Surgery Date" ], rows.first
      assert_match(/filename="short_2026-03-01_2026-03-03\.csv"/, response.headers["Content-Disposition"])
      get export_url(:surgery_list), params: RANGE.merge(view: "surgery")
      assert_response :not_found
    end
  end

  test "the mine filter narrows the surgeries" do
    hospitalization = hospitalizations(:one)
    hospitalization.update_columns(reservation_doctor_id: users(:admin).id)
    surgeries(:one).update_columns(hospitalization_id: hospitalization.id)
    get export_url(:surgery_list), params: RANGE.merge(view: "surgery", mine: "1")
    table = rows
    assert_equal 1, table.size - 1
    assert_equal "2026-03-01", table[1][table.first.index("Surgery Date")]
  end

  test "the team filter narrows the surgeries and exports the team" do
    surgeries(:two).update_columns(team_id: teams(:blue).id)
    with_site_config("features" => { "teams" => true }) do
      get export_url(:surgery_list), params: RANGE.merge(view: "surgery", team_id: teams(:blue).id)
      table = rows
      assert_equal 1, table.size - 1
      assert_equal "Blue Team", table[1][table.first.index("Team")]
    end
  end

  test "the examination tab exports the non-surgery admissions it lists" do
    hospitalizations(:one).update_columns(purpose: "examination", scheduled_procedure_date: Date.new(2026, 3, 2), procedure_name: "Endoscopy")
    hospitalizations(:two).update_columns(purpose: "surgery")
    get export_url(:admission_list), params: RANGE.merge(view: "examination")
    assert_response :success
    table = rows
    assert_equal 1, table.size - 1
    assert_equal "Endoscopy", table[1][table.first.index("Procedure Name")]
    assert_match(/filename="admission_list_2026-03-01_2026-03-03\.csv"/, response.headers["Content-Disposition"])
  end

  test "the hospitalization list export applies the list's filters" do
    get export_url(:admission_list), params: { view: "hospitalizations", keyword: "Jane" }
    table = rows
    assert_equal [ "H002" ], table.drop(1).map { |row| row[table.first.index("Patient ID")] }
    assert_match(/filename="admission_list_all\.csv"/, response.headers["Content-Disposition"])

    get export_url(:admission_list), params: { view: "hospitalizations", admitted_from: "2026-05-01", admitted_to: "2026-12-31" }
    assert_match(/filename="admission_list_2026-05-01_2026-12-31\.csv"/, response.headers["Content-Disposition"])
    assert_equal 2, rows.size - 1

    get export_url(:admission_list), params: { view: "hospitalizations" }
    assert_equal Hospitalization.active.count, rows.size - 1
  end

  test "each export is written to the access log" do
    assert_difference "AccessLog.where(event: 'export').count", 1 do
      get export_url(:surgery_list), params: RANGE.merge(view: "surgery", mine: "1")
    end
    log = AccessLog.recent_first.first
    assert_equal users(:admin), log.user
    assert_equal "export", log.event
    assert_includes log.last_url, "/exports/surgery_list"
    assert_includes log.last_url, "start=2026-03-01"
    assert_includes log.last_url, "mine=1"
  end

  test "a failed or refused export leaves no log entry" do
    assert_no_difference "AccessLog.count" do
      get export_url(:nope), params: RANGE.merge(view: "surgery")
    end
  end

  # Rows come with every association filled in, so the preloads of the few
  # rows are the same ones the many rows need.
  def add_surgery_case(index)
    patient = Patient.create!(hospital_id: "Q#{index}", name: "Extra #{index}", date_of_birth: Date.new(1970, 1, 1))
    hospitalization = Hospitalization.create!(patient: patient, scheduled_admission_date: Date.new(2026, 3, 1), reservation_doctor: users(:member),
                                              created_by: users(:admin), team: teams(:blue), source_department: departments(:gynecology),
                                              transfer_status: "transferred_in",
                                              hospitalization_diagnoses: [ HospitalizationDiagnosis.new(diagnosis: diagnoses(:pneumonia)) ])
    Surgery.create!(patient: patient, hospitalization: hospitalization, surgery_date: Date.new(2026, 3, 2), anesthesia_method: "General",
                    team: teams(:blue), surgical_device: surgical_devices(:robot_a), surgery_location: surgery_locations(:cath_lab),
                    performing_department: departments(:gynecology), slot_category: "simultaneous", department: departments(:cardiovascular_surgery),
                    surgery_procedure_selections: [ SurgeryProcedureSelection.new(surgery_procedure: surgery_procedures(:appendectomy)) ])
  end

  test "the query count does not depend on the number of rows" do
    with_site_config("features" => { "teams" => true }) do
      2.times { |i| add_surgery_case(i) }
      get export_url(:surgery_list), params: RANGE.merge(view: "surgery") # warm up
      few = count_queries { get export_url(:surgery_list), params: RANGE.merge(view: "surgery") }
      4.times { |i| add_surgery_case(10 + i) }
      many = count_queries { get export_url(:surgery_list), params: RANGE.merge(view: "surgery") }
      assert_equal few, many
      assert_equal 7 + 6, rows.size - 1
    end
  end

  test "the hospitalization exports also keep a constant query count" do
    with_site_config("features" => { "teams" => true }) do
      2.times { |i| add_surgery_case(i) }
      get export_url(:admission_list), params: { view: "hospitalizations" }
      few = count_queries { get export_url(:admission_list), params: { view: "hospitalizations" } }
      4.times { |i| add_surgery_case(10 + i) }
      many = count_queries { get export_url(:admission_list), params: { view: "hospitalizations" } }
      assert_equal few, many
    end
  end

  # --- the menu -------------------------------------------------------------

  test "the surgery tab offers the surgery exports with the range and filters" do
    get operations_calendar_url, params: RANGE.merge(mine: "1")
    assert_select "details#export-menu-surgery summary", text: "CSV Export"
    assert_select "details#export-menu-surgery a", text: "Surgery list" do |links|
      assert_includes links.first["href"], "/exports/surgery_list?"
      assert_includes links.first["href"], "view=surgery"
      assert_includes links.first["href"], "start=2026-03-01"
      assert_includes links.first["href"], "mine=1"
    end
    assert_select "details#export-menu-surgery a", text: "Admission list", count: 0
  end

  test "the examination tab offers the hospitalization exports" do
    get operations_calendar_url, params: RANGE.merge(view: "examination")
    assert_select "details#export-menu-examination a[href*='/exports/admission_list']", text: "Admission list"
    assert_select "details#export-menu-examination a", text: "Surgery list", count: 0
  end

  test "the hospitalization list offers the admission export with its filter" do
    get hospitalizations_url, params: { keyword: "Jane" }
    assert_select "details#export-menu-hospitalizations a[href*='/exports/admission_list'][href*='keyword=Jane']"
    get hospitalizations_url
    assert_select "details#export-menu-hospitalizations a[href*='admitted_from=']"
  end

  test "non-exporters see no export menu" do
    sign_in_as(users(:member))
    get operations_calendar_url, params: RANGE
    assert_select "details[id^=export-menu]", false
    get hospitalizations_url
    assert_select "details[id^=export-menu]", false
  end

  test "a site's label is the button text and exports can be switched off" do
    with_site_config("exports" => { "ncd_list" => { "subject" => "surgery", "fields" => [ "surgery_date" ], "label" => "NCD" } }) do
      get operations_calendar_url, params: RANGE
      assert_select "details#export-menu-surgery a", text: "NCD"
    end
    with_site_config("exports" => {}) do
      get operations_calendar_url, params: RANGE
      assert_select "details[id^=export-menu]", false
    end
  end

  test "the Japanese menu and the built-in label are translated" do
    sign_in_as(users(:japanese_admin))
    get operations_calendar_url, params: RANGE
    assert_select "details#export-menu-surgery summary", text: "CSV出力"
    assert_select "details#export-menu-surgery a", text: "手術一覧"
  end
end

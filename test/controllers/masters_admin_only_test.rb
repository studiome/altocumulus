require "test_helper"

# Master data may only be changed by administrators. Everyone signed in may
# still view the list/show pages, and may register a NEW diagnosis or surgery
# procedure from inside the picker modal (a turbo-frame request) while booking.
class MastersAdminOnlyTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  # Teams are a feature-flagged master; switch the feature on for every test.
  def run(*)
    SiteConfig.with("features" => { "teams" => true }) { super }
  end

  setup do
    sign_out
    sign_in_as(users(:member))
  end

  def assert_forbidden
    assert_redirected_to root_path
    assert_equal I18n.t("common.not_authorized"), flash[:alert]
  end

  # label => [model, [create path, params], [update url, params], delete url, new url, edit url]
  MASTERS = {
    "diagnoses" => { create: -> { [ diagnoses_url, { diagnosis: { name: "X" } } ] }, record: -> { diagnoses(:appendicitis) }, model: Diagnosis },
    "surgery_procedures" => { create: -> { [ surgery_procedures_url, { surgery_procedure: { name: "X" } } ] }, record: -> { surgery_procedures(:appendectomy) }, model: SurgeryProcedure },
    "holidays" => { create: -> { [ holidays_url, { holiday: { date: "2027-01-02", name: "X" } } ] }, record: -> { holidays(:year_end) }, model: Holiday },
    "elective_slot_rules" => { create: -> { [ elective_slot_rules_url, { elective_slot_rule: { day_of_week: 5, slot_count: 1, slot_duration_minutes: 60 } } ] }, record: -> { elective_slot_rules(:tuesday) }, model: ElectiveSlotRule },
    "departments" => { create: -> { [ departments_url, { department: { name: "X" } } ] }, record: -> { departments(:gynecology) }, model: Department },
    "surgery_locations" => { create: -> { [ surgery_locations_url, { surgery_location: { name: "X" } } ] }, record: -> { SurgeryLocation.first }, model: SurgeryLocation },
    "surgical_devices" => { create: -> { [ surgical_devices_url, { surgical_device: { name: "X" } } ] }, record: -> { SurgicalDevice.first }, model: SurgicalDevice },
    "teams" => { create: -> { [ teams_url, { team: { name: "X", color: "blue" } } ] }, record: -> { teams(:blue) }, model: Team }
  }.freeze

  MASTERS.each do |label, cfg|
    test "#{label}: non-admin can view the index" do
      get public_send("#{label}_url")
      assert_response :success
      assert_select "a[href^=?]", public_send("new_#{label.singularize}_path"), count: 0
    end

    test "#{label}: non-admin cannot update or destroy" do
      record = instance_exec(&cfg[:record])
      original = record.attributes
      patch polymorphic_url(record), params: { record.model_name.param_key => { name: "Hacked" } }
      assert_forbidden
      assert_equal original, record.reload.attributes
      assert_no_difference("#{cfg[:model]}.count") { delete polymorphic_url(record) }
      assert_forbidden
    end

    test "#{label}: non-admin cannot open edit" do
      get edit_polymorphic_url(instance_exec(&cfg[:record]))
      assert_forbidden
    end

    test "#{label}: admin can still edit and see the buttons" do
      sign_out
      sign_in_as(users(:admin))
      get public_send("#{label}_url")
      assert_select "a[href^=?]", public_send("new_#{label.singularize}_path")
      get edit_polymorphic_url(instance_exec(&cfg[:record]))
      assert_response :success
    end
  end

  %w[holidays elective_slot_rules departments surgery_locations surgical_devices teams].each do |label|
    test "#{label}: non-admin cannot new or create" do
      get public_send("new_#{label.singularize}_url")
      assert_forbidden
      url, params = instance_exec(&MASTERS.fetch(label)[:create])
      assert_no_difference("#{MASTERS.fetch(label)[:model]}.count") { post url, params: params }
      assert_forbidden
    end
  end

  test "diagnoses and procedures: non-admin cannot use the standalone new/create screens" do
    get new_diagnosis_url
    assert_forbidden
    assert_no_difference("Diagnosis.count") { post diagnoses_url, params: { diagnosis: { name: "Standalone" } } }
    get new_surgery_procedure_url
    assert_forbidden
    assert_no_difference("SurgeryProcedure.count") { post surgery_procedures_url, params: { surgery_procedure: { name: "Standalone" } } }
  end

  test "non-admin can register a diagnosis from the picker frame" do
    assert_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "Picker-made" } },
                          headers: TURBO.merge("Turbo-Frame" => "diagnosis_picker_frame")
    end
    assert_response :success
  end

  test "non-admin can register a diagnosis from the patient diagnosis modal frame" do
    assert_difference("Diagnosis.count") do
      post diagnoses_url, params: { diagnosis: { name: "Modal-made" } },
                          headers: TURBO.merge("Turbo-Frame" => "diagnosis_modal_frame")
    end
    assert_response :success
  end

  test "non-admin can open the new diagnosis form inside a frame" do
    get new_diagnosis_url, headers: TURBO.merge("Turbo-Frame" => "diagnosis_picker_frame")
    assert_response :success
  end

  test "non-admin can register a surgery procedure from the picker frame" do
    assert_difference("SurgeryProcedure.count") do
      post surgery_procedures_url, params: { surgery_procedure: { name: "Picker procedure" } },
                                   headers: TURBO.merge("Turbo-Frame" => "surgery_procedure_picker_frame")
    end
    assert_response :success
  end

  test "non-admin can still use the pickers" do
    get picker_diagnoses_url
    assert_response :success
    get picker_surgery_procedures_url
    assert_response :success
  end

  test "diagnosis and procedure show pages hide edit and delete for non-admins" do
    get diagnosis_url(diagnoses(:appendicitis))
    assert_select "a[href=?]", edit_diagnosis_path(diagnoses(:appendicitis)), count: 0
    assert_select "form[action=?]", diagnosis_path(diagnoses(:appendicitis)), count: 0
    get surgery_procedure_url(surgery_procedures(:appendectomy))
    assert_select "a[href=?]", edit_surgery_procedure_path(surgery_procedures(:appendectomy)), count: 0
  end

  test "holiday and slot rule show pages hide edit and delete for non-admins" do
    get holiday_url(holidays(:year_end))
    assert_response :success
    assert_select "a[href=?]", edit_holiday_path(holidays(:year_end)), count: 0
    get elective_slot_rule_url(elective_slot_rules(:tuesday))
    assert_response :success
    assert_select "a[href=?]", edit_elective_slot_rule_path(elective_slot_rules(:tuesday)), count: 0
  end

  test "diagnosis index shows edit links to admins only" do
    get diagnoses_url
    assert_select "a[href=?]", edit_diagnosis_path(diagnoses(:appendicitis)), count: 0
    sign_out
    sign_in_as(users(:admin))
    get diagnoses_url
    assert_select "a[href=?]", edit_diagnosis_path(diagnoses(:appendicitis))
  end

  test "slot rules index hides the add link for non-admins" do
    get elective_slot_rules_url
    assert_select "a[href^=?]", new_elective_slot_rule_path, count: 0
  end

  test "team terms: non-admin can view but not change" do
    team = teams(:blue)
    term = team_terms(:blue_autumn)
    get team_team_terms_url(team)
    assert_response :success
    assert_select "a[href=?]", new_team_team_term_path(team), count: 0
    assert_select "form[action=?]", copy_previous_team_team_terms_path(team), count: 0
    assert_select "a[href=?]", edit_team_team_term_path(team, term), count: 0

    get new_team_team_term_url(team)
    assert_forbidden
    assert_no_difference("TeamTerm.count") do
      post team_team_terms_url(team), params: { team_term: { starts_on: "2027-01-01", ends_on: "2027-02-01" } }
      assert_forbidden
      post copy_previous_team_team_terms_url(team)
      assert_forbidden
      delete team_team_term_url(team, term)
      assert_forbidden
    end
    get edit_team_team_term_url(team, term)
    assert_forbidden
    patch team_team_term_url(team, term), params: { team_term: { note: "hacked" } }
    assert_forbidden
    assert_equal "Autumn rotation", term.reload.note
  end
end

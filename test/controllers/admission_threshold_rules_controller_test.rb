require "test_helper"

class AdmissionThresholdRulesControllerTest < ActionDispatch::IntegrationTest
  test "a member can view the seven weekdays, Monday first, with the value in force" do
    sign_out
    sign_in_as(users(:member))
    AdmissionThresholdRule.create!(day_of_week: 1, threshold: 2)

    get admission_threshold_rules_url

    assert_response :success
    assert_select "tbody tr", 7
    assert_select "tbody tr:first-child", text: /Monday.*2/m
    assert_select "tbody tr:nth-child(2)", text: /Tuesday.*#{Rails.application.config.x.admission_warning_threshold}.*default/mi
    assert_select "tbody tr:last-child", text: /Sunday/
    assert_select "a[href=?]", edit_admission_threshold_rules_path, count: 0
  end

  test "an admin sees the edit button" do
    get admission_threshold_rules_url
    assert_select "a[href=?]", edit_admission_threshold_rules_path
  end

  test "a member cannot edit or update" do
    sign_out
    sign_in_as(users(:member))

    get edit_admission_threshold_rules_url
    assert_redirected_to root_path

    assert_no_difference("AdmissionThresholdRule.count") do
      patch admission_threshold_rules_url, params: { admission_threshold_rules: { "1" => "3" } }
    end
    assert_redirected_to root_path
  end

  test "the edit form has seven inputs and states the default" do
    AdmissionThresholdRule.create!(day_of_week: 3, threshold: 4)
    get edit_admission_threshold_rules_url

    assert_select "input[type=number][name^='admission_threshold_rules[']", 7
    assert_select "input[name='admission_threshold_rules[3]'][value='4']"
    assert_select "input[name='admission_threshold_rules[1]'][value]", 0
    assert_select "body", text: /#{Rails.application.config.x.admission_warning_threshold}/
  end

  test "an admin saves values and a blank deletes the weekday's row" do
    AdmissionThresholdRule.create!(day_of_week: 2, threshold: 9)

    patch admission_threshold_rules_url, params: { admission_threshold_rules: { "1" => "3", "2" => "", "6" => "0" } }

    assert_redirected_to admission_threshold_rules_path
    assert_equal({ 1 => 3, 6 => 0 }, AdmissionThresholdRule.thresholds_by_day)
  end

  test "saving is all or nothing: an invalid entry re-renders with every entry kept" do
    AdmissionThresholdRule.create!(day_of_week: 2, threshold: 9)

    patch admission_threshold_rules_url, params: { admission_threshold_rules: { "1" => "3", "2" => "", "4" => "-1", "5" => "2.5" } }

    assert_response :unprocessable_entity
    assert_equal({ 2 => 9 }, AdmissionThresholdRule.thresholds_by_day)
    assert_select "input[name='admission_threshold_rules[1]'][value='3']"
    assert_select "input[name='admission_threshold_rules[4]'][value='-1']"
    assert_select "input[name='admission_threshold_rules[5]'][value='2.5']"
    assert_select "[data-weekday='4'] .text-error"
    assert_select "[data-weekday='5'] .text-error"
    assert_select "[data-weekday='1'] .text-error", 0
  end

  test "a non-numeric entry is rejected" do
    patch admission_threshold_rules_url, params: { admission_threshold_rules: { "1" => "abc" } }
    assert_response :unprocessable_entity
    assert_equal 0, AdmissionThresholdRule.count
  end

  test "the navigation links to the screen" do
    get root_url
    assert_select "a[href=?]", admission_threshold_rules_path
  end
end

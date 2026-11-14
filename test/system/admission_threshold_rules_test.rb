require "application_system_test_case"

class AdmissionThresholdRulesSystemTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:admin))
  end

  test "an admin sets a weekday value, and blank returns to the default" do
    visit admission_threshold_rules_path
    click_on "Edit"

    fill_in "Monday", with: "3"
    click_on "Save"

    assert_text "successfully updated"
    within("tr[data-weekday='1']") { assert_text "3" }
    assert_equal({ 1 => 3 }, AdmissionThresholdRule.thresholds_by_day)

    click_on "Edit"
    fill_in "Monday", with: ""
    click_on "Save"
    assert_text "successfully updated"
    assert_equal 0, AdmissionThresholdRule.count
  end
end

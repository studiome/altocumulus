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

    # Wait on the saved table rather than the success toast, which dismisses
    # itself after 3 s and can be gone before a loaded CI run looks for it.
    assert_selector "tr[data-weekday='1']", text: "Weekday setting"
    within("tr[data-weekday='1']") { assert_text "3" }
    assert_equal({ 1 => 3 }, AdmissionThresholdRule.thresholds_by_day)

    click_on "Edit"
    fill_in "Monday", with: ""
    click_on "Save"
    assert_selector "tr[data-weekday='1']", text: "Default"
    assert_equal 0, AdmissionThresholdRule.count
  end
end

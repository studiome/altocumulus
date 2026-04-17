require "application_system_test_case"

class SurgeriesTest < ApplicationSystemTestCase
  test "diagnosis options are filtered by selected patient" do
    visit new_surgery_path

    assert_text "Right Appendicitis"
    assert_text "Hypertension"
    assert_text "Bilateral Pneumonia"

    select "H001 - John Doe", from: "Patient"

    assert_text "Right Appendicitis"
    assert_text "Hypertension"
    assert_no_text "Bilateral Pneumonia"

    select "H002 - Jane Smith", from: "Patient"

    assert_text "Bilateral Pneumonia"
    assert_no_text "Right Appendicitis"
    assert_no_text "Hypertension"
  end
end

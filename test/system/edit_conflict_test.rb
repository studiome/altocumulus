require "application_system_test_case"

class EditConflictSystemTest < ApplicationSystemTestCase
  def wait_for_live_connection
    assert_selector "turbo-cable-stream-source[connected]", visible: :all, wait: 10
  end

  # An examination admission saves without a surgery.
  def examination_hospitalization
    hospitalizations(:one).tap do |hospitalization|
      hospitalization.update_columns(purpose: "examination", scheduled_procedure_date: hospitalization.admission_date)
    end
  end

  test "the second save of the same reservation is warned, keeps the input and can overwrite" do
    hospitalization = examination_hospitalization
    visit edit_reservation_path(hospitalization)
    wait_for_live_connection
    fill_in "Preferred room (up to 2nd choice)", with: "My room"

    Current.set(user: users(:member)) { hospitalization.update!(room_preference: "Their room") }
    click_on "Save Reservation"

    assert_selector "[role=alert]", text: "Another user updated this record"
    assert_selector "[role=alert]", text: "Member User"
    assert_field "Preferred room (up to 2nd choice)", with: "My room"
    assert_equal "Their room", hospitalization.reload.room_preference

    click_on "Save anyway"

    assert_no_selector "[role=alert]", text: "Another user updated this record"
    assert_equal "My room", hospitalization.reload.room_preference
  end

  test "an open edit form gets an early notice when the record changes elsewhere" do
    hospitalization = examination_hospitalization
    visit edit_reservation_path(hospitalization)
    wait_for_live_connection
    fill_in "Preferred room (up to 2nd choice)", with: "Still typing"
    assert_no_text "Another user has just updated this record"

    hospitalization.update!(room_preference: "Changed elsewhere")

    assert_text "Another user has just updated this record"
    assert_link "Load the latest"
    assert_field "Preferred room (up to 2nd choice)", with: "Still typing"
  end

  test "a change to the patient alone does not raise the notice" do
    hospitalization = examination_hospitalization
    visit edit_reservation_path(hospitalization)
    wait_for_live_connection

    patients(:one).update!(name: "Renamed Elsewhere")

    # Best effort: the signal travels in-process and normally lands within
    # milliseconds; the model-level wiring is covered by the controller test
    # (the form watches only the hospitalization and its surgery).
    assert_no_text "Another user has just updated this record"
  end
end

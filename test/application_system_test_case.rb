require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--headless=new")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1400,1400")
  end

  # System tests drive a real (headless) browser, so signing in has to go
  # through the actual login form rather than posting directly to the
  # sessions controller (see SignInHelper in test_helper.rb for the
  # request-test version).
  def sign_in_as(user, password: SignInHelper::DEFAULT_PASSWORD)
    visit login_path
    fill_in "Email", with: user.login_id
    fill_in "Password", with: password
    click_button "Sign In"
    # Wait for the post-login redirect to fully land before the test's own
    # navigation runs; otherwise a `visit` immediately after this can race
    # the in-flight redirect from the login form's full-page submit.
    assert_text "Signed in successfully."
  end

  setup do
    sign_in_as(users(:admin))
  end

  # The patient field on the surgery/hospitalization forms opens a search
  # modal instead of a plain <select>. This drives it the same way a user
  # would: open the modal, optionally narrow the results with a keyword,
  # then click the matching result row (whose visible text is the patient's
  # `to_s`, e.g. "H001 - John Doe").
  # Same interaction for the diagnosis / procedure / related-diagnosis
  # pickers: click the field's "choose" button (optionally scoped to one row
  # of a multi-row form), then click the result inside the modal's frame.
  def choose_from_picker(button_label, frame:, dialog:, result:, keyword: nil, scope: nil)
    (scope || page).click_on button_label, match: :first
    within("turbo-frame##{frame}") do
      fill_in "Keyword", with: keyword if keyword
      click_on result
    end
    assert_no_selector "dialog##{dialog}[open]"
  end

  def choose_diagnosis(name, scope: nil, keyword: nil)
    choose_from_picker "Select Diagnosis", frame: "diagnosis_picker_frame",
                       dialog: "diagnosis_picker_modal", result: name, keyword: keyword, scope: scope
  end

  def choose_procedure(name, scope: nil, keyword: nil)
    choose_from_picker "Select Procedure", frame: "surgery_procedure_picker_frame",
                       dialog: "surgery_procedure_picker_modal", result: name, keyword: keyword, scope: scope
  end

  # Changing the patient re-renders the surgery form's diagnosis section (and
  # with it the picker link, which carries the patient id), so tests must let
  # that turbo-frame land before opening the picker.
  def await_surgery_diagnosis_fields
    assert_text "No diagnoses selected yet."
  end

  def choose_related_diagnosis(label)
    choose_from_picker "Select Diagnosis", frame: "surgery_diagnosis_picker_frame",
                       dialog: "surgery_diagnosis_picker_modal", result: label
  end

  def choose_patient(label, keyword: nil)
    click_on "Select Patient", match: :first
    within("turbo-frame#patient_picker_frame") do
      fill_in "Keyword", with: keyword if keyword
      click_on label
    end
    assert_no_selector "dialog#patient_picker_modal[open]"
  end
end

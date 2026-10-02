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
    switch_to_english
    fill_in "Email", with: user.login_id
    fill_in "Password", with: password
    click_button "Sign In"
    # Wait for the post-login redirect to fully land before the test's own
    # navigation runs; otherwise a `visit` immediately after this can race
    # the in-flight redirect from the login form's full-page submit.
    # Waits on the sign-out form, which only signed-in pages render, rather
    # than the success toast: the toast auto-dismisses after 3s, so under a
    # loaded parallel run it can fade before the assertion looks, or the
    # redirect can outlast Capybara's default wait. `visible: :all` because
    # the nav's sign-out buttons can be collapsed out of view.
    assert_selector "form[action='#{logout_path}']", visible: :all, wait: 10
  end

  # An anonymous visitor gets Japanese (ApplicationController's
  # ANONYMOUS_DEFAULT_LOCALE), and the fixture users have no saved locale, so
  # they would stay in Japanese after signing in too. The suite is written
  # against the English copy, so pick English the way a visitor would: through
  # the nav's language menu, which stores it in the session and survives the
  # sign-in. Opened by its "言語" label because that is the Japanese page's.
  # A no-op when the browser session already holds English (it can outlive a
  # single test), so the page may open in either language.
  def switch_to_english
    return if page.has_button?("Sign In", wait: 0)

    click_button "言語"
    click_button "English"
    assert_button "Sign In"
  end

  # The browser window outlives a single test, so a test that narrows it (e.g.
  # the 375px navigation check) would otherwise leave every later test in the
  # mobile layout, where the language menu sits behind the hamburger button.
  # Start each test from the configured desktop size instead.
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1400)
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
  # Waits on the picker link for the patient now held in the hidden field,
  # not just the empty-state text: that text is already on screen for the
  # previously chosen patient, so it would pass before the reload lands and
  # let the test click the stale link (opening the old patient's diagnoses).
  def await_surgery_diagnosis_fields
    patient_id = find("input[name='surgery[patient_id]']", visible: :all).value
    assert_selector "turbo-frame#surgery_patient_scoped_fields a[href$='patient_id=#{patient_id}']"
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

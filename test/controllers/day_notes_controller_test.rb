require "test_helper"

class DayNotesControllerTest < ActionDispatch::IntegrationTest
  DATE = "2026-03-04".freeze
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  CONTEXT = { start: "2026-03-01", days: "7", view: "surgery" }.freeze

  def frame_headers
    { "Turbo-Frame" => "day-note-#{DATE}" }
  end

  test "edit renders the form inside the day's frame" do
    get edit_day_note_url(DATE), params: CONTEXT, headers: frame_headers
    assert_response :success
    assert_select "turbo-frame#day-note-#{DATE}" do
      assert_select "form[action=?]", day_note_path(DATE)
      assert_select "input[name='holiday[holiday]'][type=checkbox]"
      assert_select "input[name='holiday[name]']"
      assert_select "textarea[name='holiday[note]']"
      assert_select "input[name='holiday[slot_count]']"
      assert_select "input[name='holiday[slot_duration_minutes]']"
      assert_select "input[type=hidden][name=start][value=?]", "2026-03-01"
      assert_select "a[href=?]", day_note_path(DATE, CONTEXT)
    end
  end

  test "a new note starts as a note, not a closed day" do
    get edit_day_note_url(DATE), params: CONTEXT, headers: frame_headers
    assert_select "input[name='holiday[holiday]'][type=checkbox]:not([checked])"
  end

  test "edit prefills an existing holiday and offers delete" do
    holiday = Holiday.create!(date: DATE, holiday: false, note: "Existing")
    get edit_day_note_url(DATE), params: CONTEXT, headers: frame_headers
    assert_select "textarea[name='holiday[note]']", text: "Existing"
    assert_select "form[action=?] input[name=_method][value=delete]", day_note_path(DATE)
    assert holiday.persisted?
  end

  test "show renders the read-only band content" do
    Holiday.create!(date: DATE, holiday: false, note: "Existing")
    get day_note_url(DATE), params: CONTEXT, headers: frame_headers
    assert_select "turbo-frame#day-note-#{DATE}", text: /Existing/
    assert_select "a[href=?]", edit_day_note_path(DATE, CONTEXT)
  end

  test "update creates the holiday and replaces the day's tbody" do
    assert_difference "Holiday.count", 1 do
      patch day_note_url(DATE), params: CONTEXT.merge(holiday: { holiday: "0", note: "Meeting", slot_count: "2", slot_duration_minutes: "120" }), headers: TURBO
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=day-#{DATE}]" do
      assert_select "template tbody#day-#{DATE}", text: /Meeting/
    end
    holiday = Holiday.find_by!(date: DATE)
    assert_equal 2, holiday.slot_count
    assert_not holiday.holiday?.nil?
  end

  test "update changes an existing holiday and can close the day" do
    holiday = Holiday.create!(date: DATE, holiday: false, note: "Old")
    patch day_note_url(DATE), params: CONTEXT.merge(holiday: { holiday: "1", name: "Closed", note: "New" }), headers: TURBO
    assert_response :success
    holiday.reload
    assert holiday.holiday?
    assert_equal "Closed", holiday.name
    assert_select "template tbody#day-#{DATE}", text: /Closed/
  end

  test "update re-renders the surgery tab day with its context links" do
    patch day_note_url(DATE), params: CONTEXT.merge(holiday: { holiday: "0", note: "Meeting" }), headers: TURBO
    assert_includes response.body, 'class="ledger-day"'
    assert_includes response.body, "start=2026-03-01"
  end

  test "update can replace the examination tbody" do
    patch day_note_url(DATE), params: CONTEXT.merge(view: "examination", holiday: { holiday: "0", note: "Meeting" }), headers: TURBO
    assert_includes response.body, "oc-empty"
    assert_includes response.body, "No examination admissions"
  end

  test "validation errors render inline in the frame with 422 and save nothing" do
    assert_no_difference "Holiday.count" do
      patch day_note_url(DATE), params: CONTEXT.merge(holiday: { holiday: "1", name: "" }), headers: frame_headers
    end
    assert_response :unprocessable_entity
    assert_select "turbo-frame#day-note-#{DATE} .alert-error"
  end

  test "an override without a weekday rule needs a duration" do
    patch day_note_url("2026-03-08"), params: CONTEXT.merge(holiday: { note: "Sunday", slot_count: "1" }), headers: { "Turbo-Frame" => "day-note-2026-03-08" }
    assert_response :unprocessable_entity
  end

  test "destroy clears the holiday and replaces the tbody" do
    Holiday.create!(date: DATE, holiday: false, note: "Existing")
    assert_difference "Holiday.count", -1 do
      delete day_note_url(DATE), params: CONTEXT, headers: TURBO
    end
    assert_select "turbo-stream[action=replace][target=day-#{DATE}]"
    assert_select "template tbody#day-#{DATE}", text: /Existing/, count: 0
  end

  test "an invalid date is not found" do
    get edit_day_note_url("not-a-date")
    assert_response :not_found
  end

  test "every action is admin only" do
    holiday = Holiday.create!(date: DATE, holiday: false, note: "Existing")
    sign_out
    sign_in_as(users(:member))

    get edit_day_note_url(DATE)
    assert_redirected_to root_path
    get day_note_url(DATE)
    assert_redirected_to root_path
    patch day_note_url(DATE), params: { holiday: { note: "Hacked" } }
    assert_redirected_to root_path
    assert_no_difference "Holiday.count" do
      delete day_note_url(DATE)
    end
    assert_redirected_to root_path
    assert_equal "Existing", holiday.reload.note
  end
end

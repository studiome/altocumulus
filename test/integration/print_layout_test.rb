require "test_helper"

# The legacy system had a paper workflow for the day-by-day operations sheet
# and the per-reservation hospitalization record, so both need to come out
# readable on paper. These tests pin down the print-only utility classes
# (Tailwind's built-in `print:` variant, not hand-written CSS) that hide
# screen-only chrome -- header nav, filter forms, and action buttons -- when
# printed, and that the substantive content is not itself hidden.
class PrintLayoutTest < ActionDispatch::IntegrationTest
  test "the header navigation and footer are hidden when printed" do
    get root_path

    assert_select "header.app-navbar.print\\:hidden"
    assert_select "footer.print\\:hidden"
  end

  test "operations calendar hides its filter form in print but keeps the day list" do
    get operations_calendar_url

    assert_select "form.print\\:hidden[action='#{operations_calendar_path}']"
    assert_select ".oc-day", 50
    assert_select ".oc-day.print\\:hidden", false
  end

  test "hospitalization detail hides edit/delete/admin controls in print but keeps the record content" do
    hospitalization = hospitalizations(:one)

    get hospitalization_url(hospitalization)

    assert_select ".card-actions.print\\:hidden a[href='#{edit_hospitalization_path(hospitalization)}']"
    assert_select ".card-actions.print\\:hidden form[action='#{hospitalization_path(hospitalization)}']"
    assert_select ".divider.print\\:hidden", text: "Admin Actions"
    assert_select ".divider:not(.print\\:hidden)", text: "Information"
  end
end

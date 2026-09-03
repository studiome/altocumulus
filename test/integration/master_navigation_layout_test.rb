require "test_helper"

class MasterNavigationLayoutTest < ActionDispatch::IntegrationTest
  test "master navigation uses a positioned daisyUI dropdown with working links" do
    get root_path

    assert_select "details.dropdown.dropdown-end", 1
    assert_select "details.dropdown.dropdown-end > summary.btn.btn-ghost", text: "Masters"
    assert_select "details.dropdown.dropdown-end > ul.dropdown-content.menu", 1

    assert_select "details.dropdown.dropdown-end > ul > li > a[href='#{diagnoses_path}']", text: "Diagnoses"
    assert_select "details.dropdown.dropdown-end > ul > li > a[href='#{surgery_procedures_path}']", text: "Procedures"
    assert_select "details.dropdown.dropdown-end > ul > li > a[href='#{elective_slot_rules_path}']", text: "Slot Rules"
    assert_select "details.dropdown.dropdown-end > ul > li > a[href='#{holidays_path}']", text: "Holidays"
  end
end

require "test_helper"

class MasterNavigationLayoutTest < ActionDispatch::IntegrationTest
  test "master navigation uses an unclipped daisyUI dropdown with working links" do
    get root_path

    assert_select "li.dropdown.dropdown-end", 1
    assert_select "li.dropdown.dropdown-end details", 0
    assert_select "li.dropdown.dropdown-end > button.btn.btn-ghost[type='button'][tabindex='0']", text: "Masters"
    assert_select "li.dropdown.dropdown-end > ul.dropdown-content.menu", 1

    assert_select "li.dropdown.dropdown-end > ul > li > a[href='#{diagnoses_path}']", text: "Diagnoses"
    assert_select "li.dropdown.dropdown-end > ul > li > a[href='#{surgery_procedures_path}']", text: "Procedures"
    assert_select "li.dropdown.dropdown-end > ul > li > a[href='#{elective_slot_rules_path}']", text: "Slot Rules"
    assert_select "li.dropdown.dropdown-end > ul > li > a[href='#{holidays_path}']", text: "Holidays"
  end
end

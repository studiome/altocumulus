require "test_helper"

class MasterNavigationLayoutTest < ActionDispatch::IntegrationTest
  # The nav now groups its growing item count into a few daisyUI dropdowns
  # (Masters, Reports, and -- for admins -- Admin) inside the desktop menu,
  # plus a separate mobile hamburger menu that lists everything flat (see
  # NavigationTest for the no-horizontal-overflow system test). Multiple
  # `li.dropdown.dropdown-end` elements now legitimately coexist, so this
  # test locates the Masters dropdown specifically by its trigger text
  # instead of assuming it is the only one on the page.
  test "master navigation uses an unclipped daisyUI dropdown with aligned trigger and working links" do
    get root_path

    masters_triggers = css_select("li.dropdown.dropdown-end > button[type='button'][tabindex='0']")
                          .select { |node| node.text.strip == "Masters" }
    assert_equal 1, masters_triggers.length, "expected exactly one Masters dropdown trigger"

    masters_li = masters_triggers.first.parent
    assert_equal "li", masters_li.name
    assert_equal %w[dropdown dropdown-end], masters_li["class"].split

    assert_nil masters_li.at_css("details")
    assert_nil masters_li.at_css("> button.btn")
    assert_nil masters_li.at_css("> button.btn-ghost")

    masters_menu = masters_li.at_css("> ul.dropdown-content.menu")
    assert masters_menu, "expected the Masters trigger to have a sibling ul.dropdown-content.menu"

    assert masters_menu.at_css("li > a[href='#{diagnoses_path}']")
    assert masters_menu.at_css("li > a[href='#{surgery_procedures_path}']")
    assert masters_menu.at_css("li > a[href='#{elective_slot_rules_path}']")
    assert masters_menu.at_css("li > a[href='#{holidays_path}']")
  end

  test "navigation layer is above page content" do
    tailwind_source = File.read(Rails.root.join("app/assets/tailwind/application.css"))

    assert_includes tailwind_source, "@apply navbar relative z-50"
  end

  test "admin-only navigation links are hidden from a non-admin user" do
    sign_out
    sign_in_as(users(:member))

    get root_path

    assert_select "a[href='#{admin_users_path}']", false
    assert_select "a[href='#{admin_announcements_path}']", false
    assert_select "a[href='#{admin_admin_notes_path}']", false
  end

  test "admin-only navigation links are shown to an admin" do
    get root_path

    assert_select "a[href='#{admin_users_path}']"
    assert_select "a[href='#{admin_announcements_path}']"
    assert_select "a[href='#{admin_admin_notes_path}']"
  end
end

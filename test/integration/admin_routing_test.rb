require "test_helper"

# Admin::UsersController and Admin::AnnouncementsController do not implement
# every action `resources` would otherwise route to. Only `show` links are
# missing (there is no such action anywhere in the app), so those routes
# should not exist at all rather than 500ing when hit. `update` (both
# resources) and `destroy` (announcements only) are real, actively used
# actions and must keep working.
class AdminRoutingTest < ActionDispatch::IntegrationTest
  test "GET /admin/users/:id is not routed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/users/1", method: :get)
    end
  end

  test "DELETE /admin/users/:id is not routed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/users/1", method: :delete)
    end
  end

  test "GET /admin/announcements/:id is not routed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/announcements/1", method: :get)
    end
  end

  test "admin user update route still works" do
    @admin = users(:admin)
    @member = users(:member)

    patch admin_user_url(@member), params: { user: { name: @member.name, email: @member.email, role: "admin", active: true } }
    assert_redirected_to admin_users_url
  end

  test "admin can still reset a user's password" do
    @member = users(:member)

    patch reset_password_admin_user_url(@member)
    assert_redirected_to admin_users_url
  end

  test "announcement update route still works" do
    announcement = announcements(:published_one)

    patch admin_announcement_url(announcement), params: { announcement: { title: "Updated title", body: announcement.body, published: false } }
    assert_redirected_to admin_announcements_url
  end

  test "announcement destroy route still works" do
    announcement = announcements(:published_one)

    assert_difference("Announcement.count", -1) do
      delete admin_announcement_url(announcement)
    end
    assert_redirected_to admin_announcements_url
  end
end

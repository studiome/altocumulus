require "test_helper"

class Admin::AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @announcement = announcements(:published_one)
  end

  test "admin can view the announcement list" do
    get admin_announcements_url
    assert_response :success
    assert_match(/Winter schedule notice/, @response.body)
  end

  test "member cannot view the announcement list" do
    sign_out
    sign_in_as(users(:member))

    get admin_announcements_url
    assert_redirected_to root_url
  end

  test "member cannot reach the new announcement form" do
    sign_out
    sign_in_as(users(:member))

    get new_admin_announcement_url
    assert_redirected_to root_url
  end

  test "admin can create an announcement" do
    assert_difference("Announcement.count", 1) do
      post admin_announcements_url, params: { announcement: { title: "New notice", body: "Body text", published: true } }
    end
    assert_redirected_to admin_announcements_url
  end

  test "member cannot create an announcement" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("Announcement.count") do
      post admin_announcements_url, params: { announcement: { title: "New notice", body: "Body text" } }
    end
    assert_redirected_to root_url
  end

  test "admin can update an announcement" do
    patch admin_announcement_url(@announcement), params: { announcement: { title: "Updated title", body: @announcement.body, published: false } }
    assert_redirected_to admin_announcements_url
    assert_equal "Updated title", @announcement.reload.title
    assert_not @announcement.published
  end

  test "admin can delete an announcement" do
    assert_difference("Announcement.count", -1) do
      delete admin_announcement_url(@announcement)
    end
    assert_redirected_to admin_announcements_url
  end

  test "member cannot delete an announcement" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("Announcement.count") do
      delete admin_announcement_url(@announcement)
    end
    assert_redirected_to root_url
  end
end

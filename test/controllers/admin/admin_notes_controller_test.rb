require "test_helper"

class Admin::AdminNotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @note = admin_notes(:one)
  end

  test "admin can view the admin note list" do
    get admin_admin_notes_url
    assert_response :success
    assert_match(/Room 3 OR table/, @response.body)
  end

  test "member cannot view the admin note list" do
    sign_out
    sign_in_as(users(:member))

    get admin_admin_notes_url
    assert_redirected_to root_url
  end

  test "admin can create a note, recorded under the current user" do
    assert_difference("AdminNote.count", 1) do
      post admin_admin_notes_url, params: { admin_note: { body: "New note" } }
    end
    assert_redirected_to admin_admin_notes_url
    assert_equal users(:admin), AdminNote.last.user
  end

  test "member cannot create a note" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("AdminNote.count") do
      post admin_admin_notes_url, params: { admin_note: { body: "New note" } }
    end
    assert_redirected_to root_url
  end

  test "admin can delete a note" do
    assert_difference("AdminNote.count", -1) do
      delete admin_admin_note_url(@note)
    end
    assert_redirected_to admin_admin_notes_url
  end

  test "member cannot delete a note" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("AdminNote.count") do
      delete admin_admin_note_url(@note)
    end
    assert_redirected_to root_url
  end
end

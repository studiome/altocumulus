require "test_helper"

# The protocol master is a MasterRecord edited by admins, but the picker modal
# on the reservation / hospitalization forms lets any signed-in user look
# protocols up and register a new one (a turbo-frame request), like surgery
# procedures.
class ChemotherapyProtocolsControllerTest < ActionDispatch::IntegrationTest
  TURBO = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze
  FRAME = TURBO.merge("Turbo-Frame" => "chemotherapy_protocol_picker_frame").freeze

  setup do
    sign_out
    sign_in_as(users(:member))
  end

  def assert_forbidden
    assert_redirected_to root_path
    assert_equal I18n.t("common.not_authorized"), flash[:alert]
  end

  test "a non-admin opens the picker, which lists active protocols in master order" do
    get picker_chemotherapy_protocols_url
    assert_response :success
    names = css_select("button[data-picker-label]").map { |node| node["data-picker-label"] }
    assert_equal [ "Protocol A", "Protocol B" ], names
    assert_select "button[data-picker-id='#{chemotherapy_protocols(:protocol_a).id}']"
    assert_select "[data-picker-result-event-value='protocol:picked']"
    assert_select "a[href=?]", new_chemotherapy_protocol_path
  end

  test "the picker follows master position, not the name" do
    chemotherapy_protocols(:protocol_a).update!(position: 9)
    get picker_chemotherapy_protocols_url
    assert_equal [ "Protocol B", "Protocol A" ], css_select("button[data-picker-label]").map { |node| node["data-picker-label"] }
  end

  test "the picker filters by keyword" do
    get picker_chemotherapy_protocols_url, params: { keyword: "protocol b" }
    assert_equal [ "Protocol B" ], css_select("button[data-picker-label]").map { |node| node["data-picker-label"] }
    get picker_chemotherapy_protocols_url, params: { keyword: "nothing like this" }
    assert_select "button[data-picker-label]", count: 0
    assert_select ".app-empty-state"
  end

  test "the picker matches _ and % literally" do
    ChemotherapyProtocol.create!(name: "FOLFOX_4")
    ChemotherapyProtocol.create!(name: "FOLFOX 4")
    ChemotherapyProtocol.create!(name: "100% dose")
    get picker_chemotherapy_protocols_url, params: { keyword: "FOLFOX_" }
    assert_equal [ "FOLFOX_4" ], css_select("button[data-picker-label]").map { |node| node["data-picker-label"] }
    get picker_chemotherapy_protocols_url, params: { keyword: "%" }
    assert_equal [ "100% dose" ], css_select("button[data-picker-label]").map { |node| node["data-picker-label"] }
  end

  test "the picker leaves out inactive protocols" do
    get picker_chemotherapy_protocols_url
    assert_select "button[data-picker-label=?]", "Retired Protocol", count: 0
  end

  test "the picker requires sign in" do
    sign_out
    get picker_chemotherapy_protocols_url
    assert_redirected_to login_url
  end

  test "a non-admin opens the new form inside the picker frame" do
    get new_chemotherapy_protocol_url, headers: FRAME
    assert_response :success
    assert_select "turbo-frame#chemotherapy_protocol_picker_frame form"
  end

  test "a non-admin registers a protocol from the picker frame: active, next position, success frame" do
    last = ChemotherapyProtocol.maximum(:position)
    assert_difference("ChemotherapyProtocol.count") do
      post chemotherapy_protocols_url, params: { chemotherapy_protocol: { name: "Modal made" } }, headers: FRAME
    end
    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    created = ChemotherapyProtocol.find_by!(name: "Modal made")
    assert created.active?
    assert_equal last + 1, created.position
    assert_includes response.body, "protocol:picked"
    assert_includes response.body, %(data-picker-id="#{created.id}")
    assert_includes response.body, %(data-picker-label="Modal made")
  end

  test "a non-admin cannot set position or active from the modal" do
    post chemotherapy_protocols_url, params: { chemotherapy_protocol: { name: "Sneaky", position: 99, active: "0" } }, headers: FRAME
    created = ChemotherapyProtocol.find_by!(name: "Sneaky")
    assert created.active?
    assert_not_equal 99, created.position
  end

  test "a duplicate name from the modal re-renders the form in the frame with 422" do
    assert_no_difference("ChemotherapyProtocol.count") do
      post chemotherapy_protocols_url, params: { chemotherapy_protocol: { name: "Protocol A" } }, headers: FRAME
    end
    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "chemotherapy_protocol_picker_frame"
    assert_includes response.body, "alert-error"
  end

  test "the standalone new, create, edit, update and destroy stay admin-only" do
    protocol = chemotherapy_protocols(:protocol_a)
    get new_chemotherapy_protocol_url
    assert_forbidden
    assert_no_difference("ChemotherapyProtocol.count") do
      post chemotherapy_protocols_url, params: { chemotherapy_protocol: { name: "Standalone" } }
    end
    assert_forbidden
    get edit_chemotherapy_protocol_url(protocol)
    assert_forbidden
    patch chemotherapy_protocol_url(protocol), params: { chemotherapy_protocol: { name: "Hacked" } }, headers: FRAME
    assert_forbidden
    assert_equal "Protocol A", protocol.reload.name
    assert_no_difference("ChemotherapyProtocol.count") { delete chemotherapy_protocol_url(protocol), headers: FRAME }
    assert_forbidden
  end

  test "an admin still gets the full-page new form and creates with every field" do
    sign_out
    sign_in_as(users(:admin))
    get new_chemotherapy_protocol_url
    assert_response :success
    assert_select "h1"
    assert_select "input[name='chemotherapy_protocol[position]']"
    post chemotherapy_protocols_url, params: { chemotherapy_protocol: { name: "Admin made", position: 7, active: "0" } }
    assert_redirected_to chemotherapy_protocols_url
    assert_not ChemotherapyProtocol.find_by!(name: "Admin made").active?
  end

  test "a department cannot be created by a non-admin, even through a turbo-frame request" do
    assert_no_difference("Department.count") do
      post departments_url, params: { department: { name: "Sneaky" } }, headers: FRAME
    end
    assert_forbidden
    get new_department_url, headers: FRAME
    assert_forbidden
  end
end

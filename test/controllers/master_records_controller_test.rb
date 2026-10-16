require "test_helper"

# Department / SurgeryLocation / SurgicalDevice share one generic CRUD
# (MasterRecordsController), so one table drives the same tests for all three.
class MasterRecordsControllerTest < ActionDispatch::IntegrationTest
  MASTERS = {
    Department => { path: :departments, singular: :department, active: :gynecology, inactive: :closed_department, referenced_by: :department_id },
    SurgeryLocation => { path: :surgery_locations, singular: :surgery_location, active: :cath_lab, inactive: :closed_room, referenced_by: :surgery_location_id },
    SurgicalDevice => { path: :surgical_devices, singular: :surgical_device, active: :robot_a, inactive: :retired_robot, referenced_by: :surgical_device_id }
  }.freeze

  MASTERS.each do |klass, cfg|
    fixtures_name = cfg[:path]
    label = klass.name.underscore

    test "#{label}: index lists records in order, including inactive ones" do
      get public_send("#{cfg[:path]}_url")
      assert_response :success
      names = css_select("tbody td.master-name").map { |node| node.text.strip }
      assert_equal klass.ordered.map(&:name), names
      assert_select "span.badge", text: "Inactive"
    end

    test "#{label}: new renders" do
      get public_send("new_#{cfg[:singular]}_url")
      assert_response :success
      assert_select "input[name='#{cfg[:singular]}[name]']"
      assert_select "input[name='#{cfg[:singular]}[position]']"
      assert_select "input[type=checkbox][name='#{cfg[:singular]}[active]']"
    end

    test "#{label}: create" do
      assert_difference("#{klass}.count") do
        post public_send("#{cfg[:path]}_url"), params: { cfg[:singular] => { name: "Created Name", position: 7, active: "0" } }
      end
      assert_redirected_to public_send("#{cfg[:path]}_url")
      created = klass.find_by!(name: "Created Name")
      assert_equal 7, created.position
      assert_not created.active?
    end

    test "#{label}: create with a blank or duplicate name re-renders the form" do
      assert_no_difference("#{klass}.count") do
        post public_send("#{cfg[:path]}_url"), params: { cfg[:singular] => { name: "" } }
      end
      assert_response :unprocessable_entity

      assert_no_difference("#{klass}.count") do
        post public_send("#{cfg[:path]}_url"), params: { cfg[:singular] => { name: klass.first.name } }
      end
      assert_response :unprocessable_entity
    end

    test "#{label}: edit and update" do
      record = send(fixtures_name, cfg[:active])
      get public_send("edit_#{cfg[:singular]}_url", record)
      assert_response :success

      patch public_send("#{cfg[:singular]}_url", record), params: { cfg[:singular] => { name: "Renamed", active: "0" } }
      assert_redirected_to public_send("#{cfg[:path]}_url")
      assert_equal "Renamed", record.reload.name
      assert_not record.active?
    end

    test "#{label}: update with invalid data re-renders" do
      record = send(fixtures_name, cfg[:active])
      patch public_send("#{cfg[:singular]}_url", record), params: { cfg[:singular] => { name: "" } }
      assert_response :unprocessable_entity
    end

    test "#{label}: destroy an unused record" do
      record = klass.create!(name: "Disposable")
      assert_difference("#{klass}.count", -1) do
        delete public_send("#{cfg[:singular]}_url", record)
      end
      assert_redirected_to public_send("#{cfg[:path]}_url")
    end

    test "#{label}: a record in use is not destroyed and the reason is shown" do
      record = send(fixtures_name, cfg[:active])
      surgeries(:one).update_columns(cfg[:referenced_by] => record.id)

      assert_no_difference("#{klass}.count") do
        delete public_send("#{cfg[:singular]}_url", record)
      end
      assert_redirected_to public_send("#{cfg[:path]}_url")
      follow_redirect!
      assert_select ".alert-error"
    end

    test "#{label}: requires sign in" do
      sign_out
      get public_send("#{cfg[:path]}_url")
      assert_redirected_to login_url
    end
  end
end

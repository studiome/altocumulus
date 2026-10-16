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

  # --- weekly special slot lane counts (SurgeryLocation / SurgicalDevice) ---

  { SurgeryLocation => [ :surgery_location, :cath_lab ], SurgicalDevice => [ :surgical_device, :robot_a ] }.each do |klass, (singular, fixture)|
    test "#{singular}: the form has one lane count input per weekday, with localized names" do
      get public_send("edit_#{singular}_url", send(klass.table_name, fixture))
      assert_select "input[type=number][name='#{singular}[special_slot_counts][#{0}]']"
      (0..6).each do |wday|
        assert_select "input[type=number][name='#{singular}[special_slot_counts][#{wday}]'][min='0'][step='1']"
      end
      assert_select "label", text: I18n.t("date.day_names")[1]
    end

    test "#{singular}: lane counts are saved from the form and listed on the index" do
      record = send(klass.table_name, fixture)
      patch public_send("#{singular}_url", record), params: { singular => { special_slot_counts: { "1" => "2", "2" => "", "4" => "1" } } }
      assert_redirected_to public_send("#{klass.table_name}_url")
      assert_equal({ 1 => 2, 4 => 1 }, record.reload.special_slot_counts)

      get public_send("#{klass.table_name}_url")
      assert_select "tr", text: /#{record.name}/ do
        assert_select ".special-slot-counts", text: /#{Regexp.escape(I18n.t("date.abbr_day_names")[1])}\s*2/
      end
    end
  end

  test "departments have no lane count inputs" do
    get edit_department_url(departments(:gynecology))
    assert_select "input[name*='special_slot_counts']", false
  end
end

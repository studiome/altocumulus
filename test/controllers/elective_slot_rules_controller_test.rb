require "test_helper"

class ElectiveSlotRulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @elective_slot_rule = elective_slot_rules(:tuesday)
  end

  test "should get index" do
    get elective_slot_rules_url
    assert_response :success
  end

  test "index lists all seven days including unconfigured ones" do
    get elective_slot_rules_url
    assert_response :success
    assert_match(/Tuesday/, @response.body)
    assert_match(/Not configured/, @response.body)
  end

  test "should get new" do
    get new_elective_slot_rule_url
    assert_response :success
  end

  test "new prefills day_of_week from the query param" do
    get new_elective_slot_rule_url, params: { day_of_week: 4 }
    assert_response :success
    assert_select "option[selected][value='4']"
  end

  test "should create elective_slot_rule" do
    assert_difference("ElectiveSlotRule.count") do
      post elective_slot_rules_url, params: { elective_slot_rule: { day_of_week: 4, slot_count: 2, slot_duration_minutes: 120 } }
    end

    assert_redirected_to elective_slot_rule_url(ElectiveSlotRule.last)
  end

  test "should reject a duplicate day_of_week" do
    assert_no_difference("ElectiveSlotRule.count") do
      post elective_slot_rules_url, params: { elective_slot_rule: { day_of_week: @elective_slot_rule.day_of_week, slot_count: 1, slot_duration_minutes: 60 } }
    end

    assert_response :unprocessable_entity
  end

  test "should show elective_slot_rule" do
    get elective_slot_rule_url(@elective_slot_rule)
    assert_response :success
  end

  test "should get edit" do
    get edit_elective_slot_rule_url(@elective_slot_rule)
    assert_response :success
  end

  test "should update elective_slot_rule" do
    patch elective_slot_rule_url(@elective_slot_rule), params: { elective_slot_rule: { slot_count: 5, slot_duration_minutes: 90 } }

    assert_redirected_to elective_slot_rule_url(@elective_slot_rule)
    @elective_slot_rule.reload
    assert_equal 5, @elective_slot_rule.slot_count
    assert_equal 90, @elective_slot_rule.slot_duration_minutes
  end

  test "create accepts a fractional slot_count and displays it without a trailing .0" do
    post elective_slot_rules_url, params: { elective_slot_rule: { day_of_week: 4, slot_count: 2.5, slot_duration_minutes: 240 } }
    rule = ElectiveSlotRule.last

    get elective_slot_rule_url(rule)
    assert_response :success
    assert_match(/2\.5/, @response.body)
  end

  test "show displays a whole slot_count without a trailing .0" do
    get elective_slot_rule_url(@elective_slot_rule) # tuesday fixture: slot_count 3
    assert_response :success
    assert_select ".card-body" do
      assert_no_match(/3\.0/, @response.body)
    end
  end

  test "index displays a whole slot_count without a trailing .0" do
    get elective_slot_rules_url
    assert_response :success
    assert_no_match(/3\.0/, @response.body)
  end

  test "should destroy elective_slot_rule" do
    assert_difference("ElectiveSlotRule.count", -1) do
      delete elective_slot_rule_url(@elective_slot_rule)
    end

    assert_redirected_to elective_slot_rules_url
  end
end

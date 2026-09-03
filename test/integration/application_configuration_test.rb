require "test_helper"

class ApplicationConfigurationTest < ActionDispatch::IntegrationTest
  test "forgery protection origin check is enabled" do
    assert ActionController::Base.forgery_protection_origin_check,
           "forgery_protection_origin_check must stay enabled; it should not be disabled for all environments"
  end

  test "time zone is set to Tokyo" do
    assert_equal "Tokyo", Rails.application.config.time_zone
  end

  test "time columns are not time zone converted" do
    assert_equal [ :datetime ], ActiveRecord::Base.time_zone_aware_types,
                 "a `time` column is a wall-clock time of day; converting it would shift every stored value"
    assert_equal "23:30", Surgery.new(start_time: "23:30").start_time_display
  end
end

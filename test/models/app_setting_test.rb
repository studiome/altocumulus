require "test_helper"

class AppSettingTest < ActiveSupport::TestCase
  test "title falls back to the configured default when nothing is stored" do
    AppSetting.delete_all

    assert_equal Rails.application.config.x.app_title, AppSetting.title
  end

  test "the configured default comes from APP_TITLE at boot" do
    with_app_title("Kohoku Clinic") do
      AppSetting.delete_all

      assert_equal "Kohoku Clinic", AppSetting.title
    end
  end

  test "a stored title wins over the configured default" do
    with_app_title("From ENV") do
      AppSetting.current.update!(title: "From the settings screen")

      assert_equal "From the settings screen", AppSetting.title
    end
  end

  test "current always resolves to the same single row" do
    AppSetting.delete_all
    AppSetting.current.update!(title: "First")
    AppSetting.current.update!(title: "Second")

    assert_equal 1, AppSetting.count
    assert_equal "Second", AppSetting.title
  end

  test "requires a title" do
    setting = AppSetting.current
    setting.title = "  "

    assert_not setting.valid?
  end

  test "rejects a title longer than the maximum" do
    setting = AppSetting.current
    setting.title = "a" * (AppSetting::MAX_TITLE_LENGTH + 1)

    assert_not setting.valid?
  end

  private

    def with_app_title(title)
      original = Rails.application.config.x.app_title
      Rails.application.config.x.app_title = title
      yield
    ensure
      Rails.application.config.x.app_title = original
    end
end

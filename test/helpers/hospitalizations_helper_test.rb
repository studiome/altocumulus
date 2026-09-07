require "test_helper"

class HospitalizationsHelperTest < ActionView::TestCase
  include HospitalizationsHelper

  test "shows the finalized length of stay once discharged" do
    assert_equal "6 days", length_of_stay_display(hospitalizations(:one))
  end

  test "shows the running day count while still admitted, labelled as ongoing" do
    travel_to Date.new(2026, 6, 4) do
      assert_equal "Day 4 (ongoing)", length_of_stay_display(hospitalizations(:three))
    end
  end

  test "shows a dash for a reservation that has not been admitted yet" do
    assert_equal "-", length_of_stay_display(hospitalizations(:four))
  end

  test "renders in Japanese under the ja locale, for all three states" do
    I18n.with_locale(:ja) do
      assert_equal "6日", length_of_stay_display(hospitalizations(:one))

      travel_to Date.new(2026, 6, 4) do
        assert_equal "入院4日目(継続中)", length_of_stay_display(hospitalizations(:three))
      end

      assert_equal "-", length_of_stay_display(hospitalizations(:four))
    end
  end
end

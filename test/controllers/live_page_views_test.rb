require "test_helper"

# The pages that refresh themselves on a live update (JS-free wiring check).
class LivePageViewsTest < ActionDispatch::IntegrationTest
  def assert_live_page(types: nil, records: nil)
    assert_response :success
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
    assert_select "[data-controller~=live-page][data-action*='live-update@window->live-page#received']" do |nodes|
      node = nodes.first
      assert (types.nil? ? node["data-live-page-types-value"].nil? : node["data-live-page-types-value"] == types)
      assert (records.nil? ? node["data-live-page-records-value"].nil? : node["data-live-page-records-value"] == records)
    end
  end

  test "list pages watch the types their rows show" do
    get patients_url
    assert_live_page(types: "Patient")

    get surgeries_url
    assert_live_page(types: "Surgery Patient")

    get hospitalizations_url
    assert_live_page(types: "Hospitalization Patient")

    get deleted_hospitalizations_url
    assert_live_page(types: "Hospitalization Patient")
  end

  test "show pages watch their own records" do
    patient = patients(:one)
    get patient_url(patient)
    assert_live_page(records: "Patient:#{patient.id}")

    hospitalization = hospitalizations(:one)
    get hospitalization_url(hospitalization)
    assert_live_page(records: "Hospitalization:#{hospitalization.id} Patient:#{hospitalization.patient_id}")

    surgery = surgeries(:one)
    surgery.update_columns(hospitalization_id: hospitalization.id)
    get surgery_url(surgery)
    assert_live_page(records: "Surgery:#{surgery.id} Patient:#{surgery.patient_id} Hospitalization:#{hospitalization.id}")
  end

  test "the sign-in page is not a live page" do
    sign_out
    get login_url
    assert_select "[data-controller~=live-page]", count: 0
  end
end

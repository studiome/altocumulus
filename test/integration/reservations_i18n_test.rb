require "test_helper"
require_relative "i18n_integration_helper"

# i18n of the reservation form and its live frames, in both locales.
class ReservationsI18nTest < ActionDispatch::IntegrationTest
  include I18nIntegrationHelper

  setup do
    @patient = patients(:three)
    @hospitalization = hospitalizations(:four)
  end

  test "every reservation screen renders in Japanese without missing translations" do
    patient_id = @patient.id
    assert_no_translation_missing [
      new_reservation_url,
      new_reservation_url(purpose: "surgery", surgery_date: "2026-11-10", patient_id: patient_id),
      new_reservation_url(purpose: "examination"),
      edit_reservation_url(@hospitalization),
      patient_card_reservations_url(patient_id: patient_id),
      patient_card_reservations_url,
      admission_calendar_reservations_url(month: "2026-11", selected: "2026-11-10"),
      admission_count_reservations_url(date: "2026-11-10"),
      admission_count_reservations_url,
      slot_summary_reservations_url(date: "2026-03-03"),
      slot_summary_reservations_url
    ], as: users(:japanese_member)
  end

  test "the team frame renders in Japanese when teams are enabled" do
    with_site_config("features" => { "teams" => true }) do
      assert_no_translation_missing [
        new_reservation_url,
        team_members_reservations_url(team_id: teams(:blue).id, date: "2026-10-15"),
        team_members_reservations_url(team_id: teams(:blue).id, date: "2020-01-01"),
        team_members_reservations_url
      ], as: users(:japanese_member)
    end
  end

  test "the form and a failed submit speak Japanese" do
    get_as users(:japanese_member), new_reservation_url, { purpose: "surgery" }
    assert_select "h1", text: "入約登録"
    assert_select "h2", text: "患者"
    assert_select "h2", text: "入院"
    assert_select "h2", text: "手術"
    assert_select "label", text: "予定入院"
    assert_select "label", text: "緊急入院"
    assert_select "summary", text: "詳細(任意)"
    assert_select "h2", text: "入約のお願い"

    post reservations_url, params: { reservation: { hospitalization: { purpose: "surgery" } } }
    assert_response :unprocessable_entity
    assert_select "[role=alert] h2", text: /入約を保存できませんでした/
  end

  test "the form speaks English" do
    get_as users(:member), new_reservation_url
    assert_select "h1", text: "New Reservation"
    assert_select "h2", text: "Reservation requests"
    assert_select "label", text: "Scheduled admission"
    assert_select "label", text: "Emergency admission"
  end
end

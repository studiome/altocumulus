require "test_helper"

class HospitalizationChemotherapyProtocolTest < ActiveSupport::TestCase
  setup do
    @protocol = chemotherapy_protocols(:protocol_a)
    @hospitalization = hospitalizations(:one)
  end

  test "protocol purposes are chemotherapy and chemoradiotherapy" do
    assert_equal %w[chemotherapy chemoradiotherapy], Hospitalization::PROTOCOL_PURPOSE_KEYS
    assert Hospitalization::PROTOCOL_PURPOSE_KEYS.all? { |key| Hospitalization::PURPOSE_KEYS.include?(key) }
  end

  test "the protocol is kept for chemotherapy and chemoradiotherapy" do
    %w[chemotherapy chemoradiotherapy].each do |purpose|
      @hospitalization.update!(purpose: purpose, chemotherapy_protocol: @protocol)
      assert_equal @protocol, @hospitalization.reload.chemotherapy_protocol, purpose
      assert @hospitalization.uses_chemotherapy_protocol?
    end
  end

  test "the protocol is cleared for any other purpose" do
    %w[surgery examination other].each do |purpose|
      @hospitalization.update!(purpose: purpose, reason: "x", chemotherapy_protocol: @protocol)
      assert_nil @hospitalization.reload.chemotherapy_protocol, purpose
      assert_not @hospitalization.uses_chemotherapy_protocol?
    end
  end

  test "switching away from chemotherapy drops the protocol" do
    @hospitalization.update!(purpose: "chemotherapy", chemotherapy_protocol: @protocol)
    @hospitalization.update!(purpose: "examination")
    assert_nil @hospitalization.reload.chemotherapy_protocol_id
  end

  test "the protocol is optional by default" do
    @hospitalization.purpose = "chemotherapy"
    assert @hospitalization.valid?
    assert_not Hospitalization.required_attribute?(:chemotherapy_protocol_id, purpose: "chemotherapy")
  end

  test "a site can require the protocol for one purpose only" do
    config = { "required_fields" => { "hospitalization_by_purpose" => { "chemotherapy" => %w[chemotherapy_protocol_id] } } }
    with_site_config(config) do
      @hospitalization.purpose = "chemotherapy"
      assert_not @hospitalization.valid?
      assert_includes @hospitalization.errors[:chemotherapy_protocol_id], I18n.t("errors.messages.blank")

      @hospitalization.chemotherapy_protocol = @protocol
      assert @hospitalization.valid?

      @hospitalization.purpose = "chemoradiotherapy"
      @hospitalization.chemotherapy_protocol = nil
      assert @hospitalization.valid?
      assert Hospitalization.required_attribute?(:chemotherapy_protocol_id, purpose: "chemotherapy")
      assert_not Hospitalization.required_attribute?(:chemotherapy_protocol_id, purpose: "chemoradiotherapy")
    end
  end

  test "rebooking keeps the protocol" do
    @hospitalization.update!(purpose: "chemotherapy", chemotherapy_protocol: @protocol)
    copy = @hospitalization.rebook(scheduled_admission_date: Date.new(2025, 1, 5))
    assert copy.persisted?, copy.errors.full_messages.to_sentence
    assert_equal @protocol, copy.chemotherapy_protocol
  end

  test "the field is labelled chemotherapy protocol in both languages" do
    assert_equal "Chemotherapy protocol", I18n.with_locale(:en) { Hospitalization.human_attribute_name(:chemotherapy_protocol_id) }
    assert_equal "化学療法プロトコル", I18n.with_locale(:ja) { Hospitalization.human_attribute_name(:chemotherapy_protocol_id) }
  end
end

require "test_helper"

class SiteConfigRequiredMarksTest < ActionView::TestCase
  def render_hospitalization_form
    view.lookup_context.prefixes = [ "hospitalizations" ]
    render partial: "hospitalizations/form", locals: {
      hospitalization: Hospitalization.new, patients: [], diagnoses: [], referral_sources: []
    }
  end

  def render_surgery_form
    view.lookup_context.prefixes = [ "surgeries" ]
    render partial: "surgeries/form", locals: {
      surgery: Surgery.new, patients: [], patient_diagnoses: [], surgery_procedures: [], elective_slot_rules: []
    }
  end

  test "surgery form has no mark on configurable fields by default" do
    render_surgery_form
    assert_select "label[for=surgery_operator_name].app-field-label-required", count: 0
    assert_select "label[for=surgery_duration_hours].app-field-label-required", count: 0
  end

  test "surgery form marks configured fields" do
    with_site_config("required_fields" => { "surgery" => %w[operator_name duration_hours] }) do
      render_surgery_form
      assert_select "label[for=surgery_operator_name].app-field-label-required", count: 1
      assert_select "label[for=surgery_duration_hours].app-field-label-required", count: 1
      assert_select "label[for=surgery_assistant_name].app-field-label-required", count: 0
    end
  end

  test "hospitalization form marks configured fields only" do
    render_hospitalization_form
    assert_select "label[for=hospitalization_referred_from].app-field-label-required", count: 0
    with_site_config("required_fields" => { "hospitalization" => %w[referred_from reservation_doctor attending_doctor] }) do
      render_hospitalization_form
      %w[referred_from reservation_doctor attending_doctor].each do |f|
        assert_select "label[for=hospitalization_#{f}].app-field-label-required", count: 1
      end
    end
    # Always-required marks stay.
    assert_select "label[for=hospitalization_purpose].app-field-label-required", count: 1
  end
end

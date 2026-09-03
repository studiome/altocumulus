require "test_helper"

class SurgeriesFormTest < ActionView::TestCase
  test "the patient_diagnosis_ids clearing hidden field renders even when no patient_diagnoses exist" do
    view.lookup_context.prefixes = [ "surgeries" ]
    surgery = Surgery.new

    render partial: "surgeries/form", locals: {
      surgery: surgery,
      patients: [],
      patient_diagnoses: [],
      surgery_procedures: [],
      hospitalizations: [],
      elective_slot_rules: []
    }

    # Without this hidden field, submitting the form with no diagnosis master
    # data present cannot clear previously linked diagnoses.
    assert_select "input[type=hidden][name='surgery[patient_diagnosis_ids][]']", minimum: 1
  end
end

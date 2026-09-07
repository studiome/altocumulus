require "test_helper"

# Cross-cutting i18n gap: `support.array` connectors. Several controllers
# flash `record.errors.full_messages.to_sentence` on a destroy/copy failure;
# without a ja override for these three connector keys, a multi-error
# Japanese flash was still joined with English connectors (", " / " and ").
class I18nToSentenceConnectorsTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "to_sentence joins multiple errors with the Japanese conjunction" do
    I18n.with_locale(:ja) do
      # words_connector/last_word_connector are both "、" (3+ items), while
      # two_words_connector is "と" (exactly 2 items) -- the same split
      # rails-i18n's own ja locale uses.
      assert_equal "A、B、C", [ "A", "B", "C" ].to_sentence
      assert_equal "AとB", [ "A", "B" ].to_sentence
    end

    assert_equal "A, B, and C", [ "A", "B", "C" ].to_sentence
  end

  test "a hospitalization copy failure with multiple validation errors joins them with the Japanese conjunction" do
    # An unparseable scheduled_admission_date trips two independent
    # validations at once: valid_date_values (:scheduled_admission_date "is
    # not a valid date") and admission_date_or_scheduled_admission_date_required
    # (:admission_date, since the invalid date casts to nil) -- a genuine
    # 2-error case for the controller's `@copy.errors.full_messages.to_sentence`
    # flash (see HospitalizationTest#"rebook does not persist with an invalid
    # scheduled_admission_date" for the same 2-error combination at the model
    # level).
    hospitalization = hospitalizations(:one)

    sign_in_as(users(:japanese_admin))

    post copy_hospitalization_url(hospitalization), params: { scheduled_admission_date: "not-a-date" }
    follow_redirect!
    assert_match "と", response.body

    sign_out
    sign_in_as(users(:admin))

    post copy_hospitalization_url(hospitalization), params: { scheduled_admission_date: "not-a-date" }
    follow_redirect!
    assert_match " and ", response.body
  end
end

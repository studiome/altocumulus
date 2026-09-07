require "test_helper"

# Stage 3 (view text externalization), group 4a: shared/_diagnosis_modal.html.erb
# (the static fallback shown before the turbo-frame lazily loads
# diagnoses/new's real content). Reuses diagnoses.new.title /
# diagnoses.new.modal_description / common.close rather than duplicating
# them, since the text is byte-identical to what group 1 already
# established for that same modal.
class SharedViewsI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "diagnosis modal shell renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get new_hospitalization_url

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
    assert_match "新規診断名", response.body
    assert_match "この診断名入力フォームを離れずに診断名マスタを作成できます。", response.body
    assert_match "読み込み中...", response.body
  end

  test "diagnosis modal shell renders unchanged in English" do
    sign_in_as(users(:member))

    get new_hospitalization_url

    assert_response :success
    assert_match "New Diagnosis", response.body
    assert_match "Create a diagnosis master without leaving this diagnosis entry form.", response.body
    assert_match "Loading...", response.body
  end

  # The modal-backdrop's dismiss button (a visually hidden hit-target
  # covering the rest of the screen, closing the dialog on click) is a
  # second, separate close control from the one in the modal header --
  # unlike that one, it had a hard-coded English "Close" aria-label that
  # never localized. Mirrors surgery_procedure_modal's backdrop button,
  # which already reused common.close correctly.
  test "diagnosis modal backdrop close button aria-label localizes to Japanese" do
    sign_in_as(users(:japanese_member))

    get new_hospitalization_url

    assert_response :success
    assert_match 'aria-label="閉じる"', response.body
    assert_no_match(/aria-label="Close"/, response.body)
  end
end

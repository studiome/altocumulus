require "test_helper"

# Stage 3 (view text externalization), group 4a: shared/_picker_modal.html.erb
# (the static fallback shown before the turbo-frame lazily loads
# diagnoses/picker's real content). The title/description are passed in by
# the rendering page -- the hospitalization form passes diagnoses.picker.* --
# so only the shell's own "Loading..." and close labels live in the partial.
class SharedViewsI18nTest < ActionDispatch::IntegrationTest
  setup { sign_out }

  test "diagnosis picker modal shell renders in Japanese" do
    sign_in_as(users(:japanese_member))

    get new_hospitalization_url

    assert_response :success
    assert_no_match(/[Tt]ranslation missing/, response.body)
    assert_match "診断名を選択", response.body
    assert_match "診断名マスタを名称で検索してください。", response.body
    assert_match "読み込み中...", response.body
  end

  test "diagnosis picker modal shell renders in English" do
    sign_in_as(users(:member))

    get new_hospitalization_url

    assert_response :success
    assert_match "Select a Diagnosis", response.body
    assert_match "Search the diagnosis master by name.", response.body
    assert_match "Loading...", response.body
  end

  # The modal-backdrop's dismiss button (a visually hidden hit-target
  # covering the rest of the screen, closing the dialog on click) is a
  # second, separate close control from the one in the modal header --
  # unlike that one, it had a hard-coded English "Close" aria-label that
  # never localized. The shared picker modal shell reuses common.close for
  # both of them.
  test "diagnosis picker modal backdrop close button aria-label localizes to Japanese" do
    sign_in_as(users(:japanese_member))

    get new_hospitalization_url

    assert_response :success
    assert_match 'aria-label="閉じる"', response.body
    assert_no_match(/aria-label="Close"/, response.body)
  end
end

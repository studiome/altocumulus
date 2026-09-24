# AGENTS.md

このファイルは、このリポジトリで作業する AI コーディングエージェント（Claude Code、Codex など）向けの共通ガイドであり、リポジトリ全体に適用する。
`CLAUDE.md` はこのファイルを `@AGENTS.md` で読み込むだけの薄いファイルとし、指示はすべてここに集約する。

## コミュニケーション

- ユーザーへの回答、進捗報告、質問、説明は常に日本語で行う。
- Git のコミットメッセージは、英語で簡潔に記述する。
- 利用可能な MCP 機能が作業に役立つ場合は、その活用を積極的に提案する。

## モデルと作業の分担

役割ごとに使うモデルを分ける。エージェントごとの対応は次の通り。

| 役割 | Claude Code | Codex |
| --- | --- | --- |
| 計画・調査 | Opus | `terra` または `sol` |
| 実装（計画後に引き継ぐ） | Sonnet | `terra` または `luna` |
| コミット作成、コミットメッセージの作成・確認 | Sonnet | `luna` |

- Claude Code で使用できるモデルが Opus 4.8 以下、Sonnet 4.6 以下の場合は、claude cli から Opus 5 / Sonnet 5 を呼び出して使用する。
- モデルやサブエージェントを指定できない環境では、上記の役割分担を可能な範囲で再現し、制約を日本語で明示する。

## 開発プロセス

- Red/Green TDD で開発する。
- まず失敗するテストを追加または確認して Red を示し、その後に最小限の実装で Green にする。
- Green を確認してから、必要に応じて振る舞いを保ったままリファクタリングする。
- テストを実行できない場合は、その理由と未検証の範囲を報告する。
- iOS, iPadOS, macOS, watchOS など Apple 製品向けのソフトウェア開発を行う場合は、Apple Human Interface Guidelines を参照し準拠する。

## Git と Pull Request

- 原則として `main` ブランチに直接コミットする形式で作業する。
- ユーザーから明示的な指示がある場合は、作業ブランチを作成して Pull Request を作る。
- コミット前に差分とテスト結果を確認する。
- ユーザーの既存の未コミット変更を、許可なく変更、破棄、またはコミットしない。

## Commands

```bash
bin/setup              # install gems, prepare db, clear logs (add --skip-server to skip starting the app)
bin/dev                # start Rails server (via rdbg) + Tailwind watcher (see Procfile.dev)
bin/rails test                              # run the full non-system test suite
bin/rails test test/models/patient_test.rb  # run a single test file
bin/rails test test/models/patient_test.rb:12  # run a single test at a line
bin/rails test:system                       # run system tests (Capybara + Selenium)
bin/rails db:prepare                        # create/migrate/seed db (used before test:system in CI)
bin/rubocop             # lint (rubocop-rails-omakase house style, config in .rubocop.yml)
bin/brakeman            # static security analysis
bin/bundler-audit       # audit gems for known vulnerabilities
bin/ci                  # runs the same checks as CI (see config/ci.rb)
```

There is no separate JS package manager/build step — JavaScript is served via `importmap-rails`, and CSS via `tailwindcss-rails` (`bin/rails tailwindcss:watch`, wired into `bin/dev`).

## Architecture

Rails 8.1 app (Propshaft + importmap + Turbo/Stimulus, no Webpack/Node build), SQLite, Solid Queue/Cache/Cable. It's a small clinical records app tracking patients, their diagnoses, surgeries, and hospitalizations.

### Domain model

- `Patient` — has many `Surgery`, `PatientDiagnosis`, `Hospitalization`.
- `Diagnosis` — a shared master list of diagnosis names (`app/models/diagnosis.rb`), referenced by both patients and hospitalizations. `restrict_with_error` on its associations, so a diagnosis in use can't be deleted.
- `PatientDiagnosis` — join of a `Patient` to a `Diagnosis`, dated (`diagnosed_on`), with a `Lateralizable` concern (`laterality`: none/left/right/bilateral) shared with `SurgeryProcedureSelection`.
- `Surgery` — belongs to `Patient`; many-to-many to `PatientDiagnosis` through `SurgeryDiagnosisLink`, and to `SurgeryProcedure` through `SurgeryProcedureSelection` (which also carries `laterality`). Validates the linked `patient_diagnoses` actually belong to the surgery's patient, and caps procedure selections at 5 with no duplicates.
- `Hospitalization` — belongs to `Patient`; many-to-many to `Diagnosis` through `HospitalizationDiagnosis`. Requires at least one diagnosis and rejects duplicates.

### Nested multi-row forms (Diagnoses/Procedures pickers)

`Hospitalization` and `Surgery` both use `accepts_nested_attributes_for` (with `allow_destroy` + `reject_if: blank id`) to let a form add/remove multiple join-row selections (diagnoses, procedures) in one submit. Each has a matching Stimulus controller (e.g. `hospitalization_diagnosis_fields_controller.js`, `surgery_procedure_fields_controller.js`) that clones a `<template>` block to add rows client-side and toggles a hidden `_destroy` field to remove them without touching the DOM structure the server rendered.

Because Rails' `params.expect` only treats purely numeric keys as nested-attribute indices, newly-added rows must use a numeric, monotonically increasing `child_index` (`Date.now()`-based) rather than a simple counter — see the comment in `hospitalization_diagnosis_fields_controller.js`.

Controllers rescue `ActiveRecord::RecordNotUnique` around the save of these nested rows (see `HospitalizationsController#save_hospitalization`) and turn it into a validation error, since swapping two existing rows' values can transiently hit a unique index mid-save even though the end state is valid.

### Bulk user registration

`UserImport` (`app/models/user_import.rb`) is a plain ActiveModel wrapping the CSV an admin uploads on `/admin/user_import/new`. `UserImport.template_csv` (served by `#template`) is the blank starting point offered on that screen: the header row alone, BOM-led, with no example rows to accidentally import. It validates the file (headers, row count, size) before `#run` saves row by row -- deliberately not in one transaction -- and returns a `Result` of per-line `Row`s (`:created` / `:skipped` / `:failed`). Existing login ids are skipped rather than updated. The form sets `data: { turbo: false }`, since the result page is a 200 render, not a redirect.

### Picker modals

Anything picked from a master list (patient, diagnosis, surgery procedure, and a surgery's related patient diagnoses) is chosen in a `<dialog>` holding a lazily loaded turbo-frame, not in a `<select>`. The patient picker has its own `patient_picker_*` controllers; everything else shares `picker_modal` (open/close), `picker_field` (the hidden input + read-only display that a `#picker` action's results fill, via a `<name>:picked` window event) and `picker_result` (turns a click on a result row — or the "record created" frame — into that event). Because one modal serves many rows, `picker_field#activate` records which field opened it and the others ignore the event.

Creating a new master record still happens inside the same modal (`Register New Diagnosis` / `Register New Procedure` link inside the picker frame): the create response replaces the picker frame with a success frame that auto-emits the same `:picked` event, so the new record lands on the waiting row.

`shared/_diagnosis_modal.html.erb` + `diagnosis_modal_controller.js` are the older create-only modal, still used by the patient diagnoses form.

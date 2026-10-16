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
- `Surgery` — belongs to `Patient`; many-to-many to `PatientDiagnosis` through `SurgeryDiagnosisLink`, and to `SurgeryProcedure` through `SurgeryProcedureSelection` (which also carries `laterality`). Validates the linked `patient_diagnoses` actually belong to the surgery's patient, and caps procedure selections at 5 with no duplicates. Optionally belongs to the `Hospitalization` it is part of (`hospitalization_id`, same patient; `HospitalizationsController#redirect_after_create` passes it to `surgeries#new`; existing surgeries were backfilled by `SurgeryHospitalizationBackfill`, `SurgeryReferralLookup` prefers the link and falls back to the date rule in `HospitalizationCoverage`), has `backup_intervention` (`involved` / `not_involved`, required for the backup slot category, cleared otherwise) and an optional `performing_department`.
- `Hospitalization` — belongs to `Patient`; many-to-many to `Diagnosis` through `HospitalizationDiagnosis`. Requires at least one diagnosis and rejects duplicates. Also carries `emergency_admission`, `transfer_status` (`none` / `transferred_in` / `operated_without_transfer`, with a required `source_department` unless `none`, cleared otherwise), `reservation_doctor` (a `User`; the old free-text column survives as `reservation_doctor_legacy_name`, shown via `reservation_doctor_display` only while no user is chosen), `created_by` (a `User`, set from `Current.user` on create only, never from params) and, for non-surgery admissions, `scheduled_procedure_date` / `procedure_name`. Has many `Surgery`.

### Nested multi-row forms (Diagnoses/Procedures pickers)

`Hospitalization` and `Surgery` both use `accepts_nested_attributes_for` (with `allow_destroy` + `reject_if: blank id`) to let a form add/remove multiple join-row selections (diagnoses, procedures) in one submit. Each has a matching Stimulus controller (e.g. `hospitalization_diagnosis_fields_controller.js`, `surgery_procedure_fields_controller.js`) that clones a `<template>` block to add rows client-side and toggles a hidden `_destroy` field to remove them without touching the DOM structure the server rendered.

Because Rails' `params.expect` only treats purely numeric keys as nested-attribute indices, newly-added rows must use a numeric, monotonically increasing `child_index` (`Date.now()`-based) rather than a simple counter — see the comment in `hospitalization_diagnosis_fields_controller.js`.

Controllers rescue `ActiveRecord::RecordNotUnique` around the save of these nested rows (see `HospitalizationsController#save_hospitalization`) and turn it into a validation error, since swapping two existing rows' values can transiently hit a unique index mid-save even though the end state is valid.

### Site configuration

Site-specific customization is a deploy-time YAML file, not code: `SiteConfig` (`app/models/site_config.rb`) reads `ENV["SITE_CONFIG_PATH"]` if set (production mounts a file there via a Kamal volume), else the committed neutral default `config/site.yml` (`config/site.example.yml` is a fully filled example). It is validated at boot (`config/initializers/site_config.rb`): unknown keys, unknown field names or an uncompilable regex raise `SiteConfig::Error`. New top-level keys go into `SiteConfig::SCHEMA` with a per-key normalizer. Current keys: `required_fields.{hospitalization,surgery}` (strict presence validation via the `ConfigurableRequiredFields` concern, evaluated at validation time; `required_fields.hospitalization_by_purpose.<purpose>` adds fields for one purpose only, so `required_attribute?` also takes the record or `purpose:`; forms mark labels with `required_label_class` / `Model.required_attribute?` so the asterisk and validation share one source) and `patient.hospital_id_format` / `hospital_id_format_hint` (`Patient` validation, only when the ID is set or changed). Tests swap it with `with_site_config(hash) { ... }`.

Site vocabulary (department names, room names, device names) must never be hardcoded in code or locale files. It lives in the admin-editable master tables `Department`, `SurgeryLocation` and `SurgicalDevice` (concern `MasterRecord`: unique name, `position` ordering, `active` flag, `choices_for(current_id)` keeps an already-used inactive record selectable on its edit form; `restrict_with_error` on deletion). They are edited through one generic `MasterRecordsController` (subclasses only name the model; views in `app/views/master_records`) and referenced from `Surgery` by `department_id` (partner department, cleared unless simultaneous/backup), `surgery_location_id` and `surgical_device_id`. The site config's `masters` key seeds them via `SiteMasterSeeder` / `bin/rails site:seed_masters` (additive and idempotent; also run from `db/seeds.rb`). `SurgeryLocation#asks_performing_department` is a hint for the future unified form (site config `masters.surgery_locations` may give `{name:, asks_performing_department:}`). Backfills of existing data (`lib/*_backfill.rb`) are plain Arel on table/column names, free of models, unit-tested on scratch tables. The data migration that replaced the old free-text `target_department` / `location` columns uses the plain-SQL `MasterBackfill` (`lib/master_backfill.rb`), which is reversible.

### Bulk user registration

`UserImport` (`app/models/user_import.rb`) is a plain ActiveModel wrapping the CSV an admin uploads on `/admin/user_import/new`. `UserImport.template_csv` (served by `#template`) is the blank starting point offered on that screen: the header row alone, BOM-led, with no example rows to accidentally import. It validates the file (headers, row count, size) before `#run` saves row by row -- deliberately not in one transaction -- and returns a `Result` of per-line `Row`s (`:created` / `:skipped` / `:failed`). Existing login ids are skipped rather than updated. The form sets `data: { turbo: false }`, since the result page is a 200 render, not a redirect.

### Roles and masters

Masters (diagnoses, surgery procedures, holidays, elective slot rules, departments, surgery locations, surgical devices, teams, team terms) are editable by administrators only: their controllers use `require_admin` (redirect to root with `common.not_authorized`) for everything except `index`/`show`, and the edit/delete/new buttons are wrapped in `admin?`. Exception: `DiagnosesController` and `SurgeryProceduresController` let any signed-in user `new`/`create` when `turbo_frame_request?` (the picker modal and the patient-diagnoses modal), via `require_admin_unless_modal`; the standalone full-page new/create screens, edit, update and destroy stay admin-only. Tests that render master forms must sign in as an admin.

### Reservation form (入約フォーム)

`Reservation` (`app/models/reservation.rb`) is an ActiveModel form object over one `Hospitalization` and, for purpose "surgery" only, one `Surgery`; `ReservationsController` (`new/create/edit/update`, `:id` = hospitalization id) renders `app/views/reservations/*`. It is how the operations calendar books (day link, "+入約", row "編集"); the separate hospitalization/surgery forms stay for admin/detail edits. Key points:

- Params are `reservation[hospitalization|surgery][...]`, `reservation[diagnoses][i][...]`, `reservation[procedures][i][...]` (rows carry `id`, picker id, `laterality`, `_destroy`; new rows use the numeric `Date.now()` index like the other nested forms and reuse the `hospitalization-diagnosis-fields` / `surgery-procedure-fields` / `picker-field` controllers). Surgery params are ignored for other purposes; the form's hidden sections are also disabled by `purpose-fields` (`data-purpose-fields-disable-hidden-value`) so they are not submitted.
- Validation is the models' own (site required fields included), merged into `errors` under `"hospitalization.x"` / `"surgery.x"` (`Reservation.human_attribute_name` maps them back); views render them with `ReservationsHelper#reservation_field_error` / `reservation_aria`.
- Saving: hospitalization, surgery, then `PatientDiagnosis` reuse-or-create + link sync, all in one transaction; a link to a diagnosis that was never one of the reservation's diagnoses is preserved. `hospitalization.scheduled_surgery_date` follows the surgery date; the performing department is cleared unless the location `asks_performing_department?`.
- Live parts are turbo-frames refreshed by the `reservation-form` Stimulus controller from the collection routes `patient_card`, `admission_count`, `admission_calendar` (side-panel month, `AdmissionCalendar`, one grouped query), `slot_summary` (`ElectiveSlotUsage`) and `team_members`; `reservation-surgery` shows the fields each slot category needs.
- After save, `calendar_path_for_saved` (CalendarReturn) sends a dated surgery to the highlighted calendar day; anything else to the hospitalization page.

### Picker modals

Anything picked from a master list (patient, diagnosis, surgery procedure, and a surgery's related patient diagnoses) is chosen in a `<dialog>` holding a lazily loaded turbo-frame, not in a `<select>`. The patient picker has its own `patient_picker_*` controllers; everything else shares `picker_modal` (open/close), `picker_field` (the hidden input + read-only display that a `#picker` action's results fill, via a `<name>:picked` window event) and `picker_result` (turns a click on a result row — or the "record created" frame — into that event). Because one modal serves many rows, `picker_field#activate` records which field opened it and the others ignore the event.

Creating a new master record still happens inside the same modal (`Register New Diagnosis` / `Register New Procedure` link inside the picker frame): the create response replaces the picker frame with a success frame that auto-emits the same `:picked` event, so the new record lands on the waiting row.

`shared/_diagnosis_modal.html.erb` + `diagnosis_modal_controller.js` are the older create-only modal, still used by the patient diagnoses form.

### Day-level slot override

`Holiday` rows with `holiday: false` may carry `slot_count` / `slot_duration_minutes` that replace the weekday `ElectiveSlotRule` for that date (a closed day must not carry them; the duration is required when the weekday has no rule). `Holiday#effective_rule_for(weekday_rule)` returns an unsaved `ElectiveSlotRule`, so `ElectiveSlotUsage` (slots, capacity, warnings, fractional last slot) needs no special case; `ElectiveSlotUsage#slot_override?` drives the "Slots: N (changed)" marker on the calendar day cell and the weekly PDF day heading.

### Teams

Behind `features.teams` in the site config (default off: screens, selects and displays are hidden, `team_id` cannot be a required field). `Team` (a `MasterRecord` plus a palette `color`) has many `TeamTerm`s (inclusive, non-overlapping date ranges) which have many `TeamTermMember`s (optional user, name, role main/sub/member, at most one main and one sub); `Team#term_for(date)` and `TeamTerm#members_display` produce the members line. `Hospitalization` and `Surgery` include `TeamAssignable` (`team_id`, `effective_team`, `team_members_display` for the date given by `team_display_date`); a surgery created for a hospitalization defaults to its team. Terms are edited under `/teams/:id/team_terms` (`TeamTermsController`, nested rows via `team_term_member_fields_controller.js` with the same `Date.now()` child_index rule as above); `copy_previous` builds the next rotation with main/sub swapped. `masters.teams` in the site config seeds teams (`SiteMasterSeeder`).

### Ledger columns

The operations calendar (HTML), the weekly PDF and the future examination calendar render rows from one registry, `LedgerColumn` (`app/models/ledger_column.rb`, definitions in `app/models/ledger_columns/{surgery,hospitalization}_columns.rb`, shared cell helpers in `cells.rb`). A column has a key, subject (`:surgery` / `:hospitalization`), a two-tier i18n header (`ledger_columns.headers.<key>.{upper,lower}`), a default PDF width, the associations it reads (`includes`, merged by `LedgerColumn.includes_for` so screens preload exactly what they show) and a builder returning a renderer-neutral `Cell` (upper/lower lists of `Segment{text, kind}`; kinds are text styles or badge kinds). `LedgerHelper` maps kinds to daisyUI classes for HTML; the PDF uses `Cell#plain_text` (monochrome). Which columns each ledger shows comes from the site config `ledger_columns.<ledger>` (validated against the registry in `SiteConfig`, `team` only with `features.teams`; omitted ledger = `LedgerColumn::LEDGERS[...][:default]`). `WeeklySurgerySchedulePdf#column_widths` takes registry widths, scales them down when over-wide and gives the last column the remainder otherwise. A new column means one registry entry, header i18n in both locales, and a unit test; keep builders free of extra queries (preload via `includes`; `Team#term_for` picks the term in memory when terms are preloaded).

### Development demo data

`bin/rails dev:demo_data` (`DevDemoData` in `lib/dev_demo_data.rb`) fills a development database with fictional, idempotently created data for UI review; it raises `DevDemoData::NotDevelopmentError` anywhere else. Never run `db:reset`/`db:schema:load` against the development database to "refresh" it; the task is additive.

### Operations calendar tabs and day notes

`OperationsCalendarController#index` renders one of two tabs chosen by `view` (`surgery` default / `examination`). `OperationsCalendar` (surgeries, via `ElectiveSlotUsage.for_dates`) and `ExaminationCalendar` (active non-surgery hospitalizations grouped by `scheduled_procedure_date || effective_admission_date`) each resolve their data in a fixed number of queries; both take a `CalendarFilter` (`mine` / `team_id`, matched in SQL; under a filter the slot-usage numbers still count every case). A day is one `<tbody id="day-DATE">` (`_day` / `_examination_day`). Admins edit a day's note through `DayNotesController` (`/day_notes/:date`, a turbo-frame per day, `require_admin`): a save re-renders that day's tbody by turbo stream, so the calendar's own params (`start`, `days`, `view`, `mine`, `team_id`, `alt`) travel with every request (`DayNotesHelper#day_note_context`).

# Japanese (like most CJK languages) has no grammatical plural: CLDR defines
# only the :other category for :ja, never :one. Without this, I18n's default
# pluralizer (lib/i18n/backend/base.rb) always requires a :one key whenever a
# translation is looked up with count: 1, so a ja.yml entry that only defines
# :other (as instructed - see e.g. models.elective_slot_usage.warnings.unscheduled)
# would raise I18n::InvalidPluralizationData the moment count happens to be 1.
#
# Enabling the Pluralization backend module restores correct CLDR behavior
# for any locale that registers an i18n.plural.rule -- see
# config/locales/plurals.rb, which registers "always :other" for :ja. English
# is untouched: with no rule registered for :en, the module falls back to the
# default one/other split, exactly as before.
require "i18n/backend/pluralization"

I18n::Backend::Simple.include(I18n::Backend::Pluralization)

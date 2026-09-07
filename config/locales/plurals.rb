# Registers I18n's CLDR-correct pluralization rule for Japanese: unlike
# English, Japanese has no grammatical plural, so CLDR defines only the
# :other category for :ja (never :one). This lets ja.yml pluralized entries
# (e.g. models.elective_slot_usage.warnings.unscheduled,
# helpers.hospitalizations.length_of_stay.days) define only :other, per the
# i18n rollout's design -- see config/initializers/pluralization.rb, which
# enables the I18n::Backend::Pluralization module that reads this rule.
#
# A plain .rb file (rather than .yml) is required here because the rule
# itself is a Ruby lambda, which YAML cannot represent. Rails automatically
# includes this in I18n.load_path alongside config/locales/*.yml, so it is
# lazily (re)loaded the same way as the rest of the locale data regardless of
# how/when I18n.backend gets (re)configured -- unlike a plain
# I18n.backend.store_translations call in an initializer, which would be
# lost if Rails' own i18n setup replaces the backend instance afterward.
{
  ja: {
    i18n: {
      plural: {
        rule: ->(count) { :other }
      }
    }
  }
}

require "test_helper"

# Guards config/locales/en.yml and config/locales/ja.yml against drifting
# apart: every key present in one should be present in the other, so a
# missing Japanese (or English) translation shows up here instead of as a
# silent "translation missing" only reachable by visiting the right screen.
#
# A few sub-trees are INTENTIONALLY asymmetric (see the design notes at
# their definition site in each locale file) and are excluded below:
#   - activerecord.attributes / activerecord.models: English relies on
#     Rails' own automatic humanize instead of an explicit translation
#     (see the note above en.yml's `activerecord:` block).
#   - helpers.submit: English relies on Rails' own default
#     "Create %{model}" / "Update %{model}" template; only Japanese (which
#     has no such built-in default) defines it explicitly.
#   - support.array: only Japanese needs custom Array#to_sentence
#     connectors: English already gets the right punctuation from
#     to_sentence's own built-in defaults.
# A `.one` pluralization key is also allowed to exist only in en.yml: Japan
# has no grammatical plural, so config/locales/plurals.rb registers a CLDR
# rule where :ja only ever resolves to :other (see that file's comments).
class I18nLocaleConsistencyTest < ActiveSupport::TestCase
  EN_PATH = Rails.root.join("config/locales/en.yml")
  JA_PATH = Rails.root.join("config/locales/ja.yml")

  INTENTIONALLY_ASYMMETRIC_PREFIXES = %w[
    activerecord.attributes
    activerecord.models
    helpers.submit
    support.array
  ].freeze

  test "en.yml and ja.yml define the same set of translation keys" do
    en_keys = flatten_keys(YAML.load_file(EN_PATH).fetch("en"))
    ja_keys = flatten_keys(YAML.load_file(JA_PATH).fetch("ja"))

    en_keys = exclude_intentional_asymmetry(en_keys)
    ja_keys = exclude_intentional_asymmetry(ja_keys)

    missing_in_ja = (en_keys - ja_keys).reject { |key| pluralization_only_key?(key, en_keys, ja_keys) }
    missing_in_en = ja_keys - en_keys

    assert_empty missing_in_ja, "keys present in en.yml but missing from ja.yml:\n#{missing_in_ja.sort.join("\n")}"
    assert_empty missing_in_en, "keys present in ja.yml but missing from en.yml:\n#{missing_in_en.sort.join("\n")}"
  end

  private

    def flatten_keys(hash, prefix = [])
      hash.each_with_object([]) do |(key, value), keys|
        path = prefix + [ key ]
        if value.is_a?(Hash)
          keys.concat(flatten_keys(value, path))
        else
          keys << path.join(".")
        end
      end
    end

    def exclude_intentional_asymmetry(keys)
      keys.reject do |key|
        INTENTIONALLY_ASYMMETRIC_PREFIXES.any? { |prefix| key == prefix || key.start_with?("#{prefix}.") }
      end
    end

    # A ".one" key is allowed to exist only on the English side, as long as
    # its ".other" sibling exists on both -- ja's CLDR plural rule never
    # selects :one, so ja.yml deliberately never defines it.
    def pluralization_only_key?(key, en_keys, ja_keys)
      return false unless key.end_with?(".one")

      other_key = key.sub(/\.one\z/, ".other")
      en_keys.include?(other_key) && ja_keys.include?(other_key)
    end
end

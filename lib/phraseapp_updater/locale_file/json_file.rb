# frozen_string_literal: true

require 'oj'

# We're working with pure JSON, not
# serialized Ruby objects
Oj.default_options = { mode: :strict }

class PhraseAppUpdater
  class LocaleFile
    class JSONFile < LocaleFile
      EXTENSION      = "json"
      PHRASEAPP_TYPE = "nested_json"

      class << self
        def load(content)
          Oj.load(content)
        rescue Oj::ParseError => e
          raise ArgumentError.new("Provided content was not valid JSON: #{e}")
        end

        def dump(hash)
          # Add indentation for better diffs
          json = Oj.dump(hash, indent: '  ', space:  ' ', object_nl: "\n", array_nl: "\n", mode: :strict)
          # Oj omits end of file newline unless using the integer form of :indent
          json << "\n"
          json
        end

        def extension
          EXTENSION
        end

        def phraseapp_type
          PHRASEAPP_TYPE
        end
      end
    end
  end
end

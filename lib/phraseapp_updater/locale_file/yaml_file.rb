require 'psych'
class PhraseAppUpdater
  class LocaleFile
    class YAMLFile < LocaleFile
      EXTENSION      = "yml"
      PHRASEAPP_TYPE = "yml"

      class << self
        def load(content)
          Psych.load(content)
        rescue Psych::SyntaxError => e
          raise ArgumentError.new("Provided content was not valid YAML")
        end

        def dump(hash)
          Psych.dump(hash)
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

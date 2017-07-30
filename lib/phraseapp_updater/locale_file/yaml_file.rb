require 'psych'
class PhraseAppUpdater
  class LocaleFile
    class YAMLFile < LocaleFile
      EXTENSION = "yml"
      def self.from_hash(name, hash)
        new(name, Psych.dump(hash))
      end

      def parse(content)
        Psych.load(content)
      rescue Psych::SyntaxError => e
        raise ArgumentError.new("Provided content was not valid YAML")
      end

      def format_content!
      end
    end
  end
end

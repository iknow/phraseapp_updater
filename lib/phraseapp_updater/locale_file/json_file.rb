require 'multi_json'
require 'oj'

# We're working with pure JSON, not
# serialized Ruby objects
Oj.default_options = {mode: :strict}

class PhraseAppUpdater
  class LocaleFile
    class JSONFile < LocaleFile
      EXTENSION = "json"
      def self.from_hash(name, hash)
        new(name, MultiJson.dump(hash))
      end

      def parse(content)
        MultiJson.load(content)
      rescue MultiJson::ParseError => e
        raise ArgumentError.new("Provided content was not valid JSON: #{e}")
      end

      def format_content!
        # Add indentation for better diffs
        @content = MultiJson.dump(MultiJson.load(@content), pretty: true)
      end
    end
  end
end


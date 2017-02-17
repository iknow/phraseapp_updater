require 'multi_json'
require 'oj'

# We're working with pure JSON, not
# serialized Ruby objects
Oj.default_options = {mode: :strict}

class PhraseAppUpdater
  class LocaleFile
    attr_reader :name, :content, :parsed_content

    def self.from_hash(name, hash)
      new(name, MultiJson.dump(hash))
    end

    def initialize(name, content)
      @name           = name
      @content        = content
      @parsed_content = parse(@content)
      format_content!
    end

    def to_s
      "#{name}, #{content[0,20]}..."
    end

    def name_with_extension
      "#{name}.json"
    end

    private

    def parse(content)
      MultiJson.load(content)
    rescue MultiJson::ParseError => e
      raise ArgumentError.new("Provided content was not valid JSON")
    end

    def format_content!
      # Add indentation for better diffs
      @content = MultiJson.dump(MultiJson.load(@content), pretty: true)
    end
  end
end


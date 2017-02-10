require 'multi_json'
require 'oj'

# We're working with pure JSON, not
# serialized Ruby objects
Oj.default_options = {mode: :strict}

class LocaleFile
  attr_reader :name, :content, :parsed_content

  def initialize(name, content)
    @name           = name
    @content        = content
    @parsed_content = MultiJson.load(@content)

  rescue MultiJson::ParseError => e
    raise ArgumentError.new("Provided content was not valid JSON")
  end
end

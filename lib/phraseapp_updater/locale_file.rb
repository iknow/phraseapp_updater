require "phraseapp_updater/locale_file/json_file"
require "phraseapp_updater/locale_file/yaml_file"

class PhraseAppUpdater
  class LocaleFile
    attr_reader :name, :content, :parsed_content

    class BadFileTypeError < StandardError ; end

    def self.from_hash(name, hash)
      raise RuntimeError.new("Must be implemented in a subclass.")
    end

    def self.class_for_file_format(type)
      case type.downcase
      when "json"
        JSONFile
      when "yml", "yaml"
        YAMLFile
      else
        raise BadFileTypeError.new("Invalid file type: #{type}")
      end
    end

    # Expects a Ruby hash
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
      "#{name}.#{self.class::EXTENSION}"
    end

    private

    def parse(content)
      raise RuntimeError.new("Must be implemented in a subclass.")
    end

    def format_content!
      raise RuntimeError.new("Must be implemented in a subclass.")
    end
  end
end


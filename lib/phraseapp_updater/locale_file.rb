require "phraseapp_updater/locale_file/json_file"
require "phraseapp_updater/locale_file/yaml_file"

class PhraseAppUpdater
  class LocaleFile
    attr_reader :name, :content, :parsed_content

    class BadFileTypeError < StandardError; end

    class << self
      def from_hash(name, hash)
        new(name, hash)
      end

      def from_file_content(name, content)
        new(name, load(content))
      end

      private :new

      def class_for_file_format(type)
        case type.downcase
        when "json"
          JSONFile
        when "yml", "yaml"
          YAMLFile
        else
          raise BadFileTypeError.new("Invalid file type: #{type}")
        end
      end

      def load(_content)
        raise RuntimeError.new("Must be implemented in a subclass.")
      end

      def dump(_hash)
        raise RuntimeError.new("Must be implemented in a subclass.")
      end
    end

    def to_s
      name
    end

    def name_with_extension
      "#{name}.#{self.class::EXTENSION}"
    end

    private

    # Expects a Ruby hash
    def initialize(name, parsed_content)
      @name           = name
      @parsed_content = normalize_hash(parsed_content)
      @content        = self.class.dump(@parsed_content)
      freeze
    end

    def normalize_hash(hash)
      hash.keys.sort_by(&:to_s).each_with_object({}) do |key, sorted_hash|
        val = hash[key]
        val = normalize_hash(val) if val.is_a?(Hash)
        key = key.to_s if key.is_a?(Symbol)
        sorted_hash[key] = val
      end
    end
  end
end

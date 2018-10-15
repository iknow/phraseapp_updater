require "phraseapp_updater/locale_file/json_file"
require "phraseapp_updater/locale_file/yaml_file"

class PhraseAppUpdater
  class LocaleFile
    attr_reader :locale_name, :content, :parsed_content

    class BadFileTypeError < StandardError; end

    class << self
      def from_hash(locale_name, hash)
        new(locale_name, hash)
      end

      def from_file_content(locale_name, content)
        new(locale_name, load(content))
      end

      def load_directory(directory)
        Dir[File.join(directory, "*.#{extension}")].map do |filename|
          load_file(filename)
        end
      end

      def load_file(filename)
        unless File.readable?(filename) && File.file?(filename)
          raise RuntimeError.new("Couldn't read localization file at #{filename}")
        end

        locale_name = File.basename(filename).chomp(".#{extension}")
        from_file_content(locale_name, File.read(filename))
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

      def extension
        raise RuntimeError.new("Abstract method")
      end

      def phraseapp_type
        raise RuntimeError.new("Abstract method")
      end

      def load(_content)
        raise RuntimeError.new("Abstract method")
      end

      def dump(_hash)
        raise RuntimeError.new("Abstract method")
      end
    end

    def to_s
      locale_name
    end

    def filename
      "#{locale_name}.#{self.class.extension}"
    end

    private

    # Expects a Ruby hash
    def initialize(locale_name, parsed_content)
      @locale_name    = locale_name
      @parsed_content = normalize_hash(parsed_content)
      @content        = self.class.dump(@parsed_content)
      freeze
    end

    def normalize_hash(hash)
      hash.keys.sort_by(&:to_s).each_with_object({}) do |key, normalized_hash|
        val = hash[key]
        next if val == '' || (val.is_a?(Hash) && val.empty?)

        val = normalize_hash(val) if val.is_a?(Hash)
        key = key.to_s if key.is_a?(Symbol)
        normalized_hash[key] = val
      end
    end
  end
end

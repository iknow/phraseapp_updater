require 'yaml'

class PhraseAppUpdater
  class YMLConfigLoader
    attr_reader :api_key, :project_id, :file_format
    def initialize(file_path)
      unless File.readable?(file_path)
        raise RuntimeError.new("Can't read config file at #{file_path}")
      end

      parsed_yaml = YAML.load(File.read(file_path))

      unless parsed_yaml
        raise RuntimeError.new("Couldn't parse file contents: #{File.read(file_path)}")
      end

      config = parsed_yaml.fetch("phraseapp")

      @api_key     = config.fetch("access_token")
      @project_id  = config.fetch("project_id")

      push_file_format = config.fetch("push").fetch("sources").first.fetch("params").fetch("file_format")
      pull_file_format = config.fetch("pull").fetch("targets").first.fetch("params").fetch("file_format")

      unless push_file_format == pull_file_format
        raise ArgumentError.new("Push and pull must be the same format")
      end

      @file_format = convert(push_file_format)
    end


    private

    def convert(phraseapp_file_format)
      case phraseapp_file_format
      when "nested_json"
        "json"
      when "yml"
        "yml"
      else
        raise ArugmentError.new("Unsupported type: #{phraseapp_file_format}")
      end
    end
  end
end

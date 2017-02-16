require 'yaml'

class PhraseAppUpdater
  class YMLConfigLoader
    attr_reader :api_key, :project_id
    def initialize(file_path)
      unless File.readable?(file_path)
        raise RuntimeError.new("Can't read config file at #{file_path}")
      end

      parsed_yaml = YAML.load(File.read(file_path))

      unless parsed_yaml
        raise RuntimeError.new("Couldn't parse file contents: #{File.read(file_path)}")
      end

      @api_key    = parsed_yaml.fetch("phraseapp").fetch("access_token")
      @project_id = parsed_yaml.fetch("phraseapp").fetch("project_id")
    end
  end
end

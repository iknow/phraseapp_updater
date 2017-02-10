require 'phraseapp_updater/locale_file'

class PhraseAppUpdater
  class LocaleFileLoader
    def self.load(filename)
      unless File.readable?(filename) && File.file?(filename)
        raise RuntimeError.new("Couldn't read localization file at #{filename}")
      end

      LocaleFile.new(File.basename(filename).chomp(".json"), File.read(filename))
    end

    def self.filenames(locale_directory)
      Dir["#{locale_directory}/*.json"]
    end
  end
end


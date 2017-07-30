require 'phraseapp_updater/locale_file'

class PhraseAppUpdater
  class LocaleFile
    class Loader
      def initialize(extension)
        @extension = extension
      end

      def load(filename)
        unless File.readable?(filename) && File.file?(filename)
          raise RuntimeError.new("Couldn't read localization file at #{filename}")
        end

        LocaleFile.class_for_file_format(@extension).new(File.basename(filename).chomp(".#{@extension}"), File.read(filename))
      end

      def filenames(locale_directory)
        Dir["#{locale_directory}/*.#{@extension}"]
      end
    end
  end
end


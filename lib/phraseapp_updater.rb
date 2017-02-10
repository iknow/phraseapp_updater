require 'phraseapp_updater/differ'
require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/locale_file_loader'
require 'phraseapp_updater/phraseapp_api'

module IndexBy
  refine Array do
    def index_by(&block)
      each_with_object({}) do |value, hash|
        hash[yield(value)] = value
      end
    end
  end
end

class PhraseAppUpdater
  using IndexBy

  def self.run(phraseapp_api_key, phraseapp_project_id, previous_locales_path, new_locales_path)
    phraseapp_api         = PhraseAppAPI.new(phraseapp_api_key, phraseapp_project_id)
    previous_locale_files = LocaleFileLoader.filenames(previous_locales_path).map { |l| LocaleFileLoader.load(l) }
    new_locale_files      = LocaleFileLoader.filenames(new_locales_path).map      { |l| LocaleFileLoader.load(l) }
    phraseapp_files       = phraseapp_api.all_locale_files

    unless previous_locale_files.map(&:name) == new_locale_files.map(&:name) && previous_locale_files.map(&:name) == phraseapp_files.map(&:name)
      message = "Number of files differs. This tool does not yet support adding or removing langauges\n\
      #{previous_locale_files.map(&:name)} #{new_locale_files.map(&:name)} #{phraseapp_files.map(&:name)}"
      raise RuntimeError.new(message)
    end

    new_locale_files = new_locale_files.index_by(&:name)
    phraseapp_files  = phraseapp_files.index_by(&:name)

    resolved_files = previous_locale_files.map do |previous_locale_file|
      new_locale_file = new_locale_files.fetch(previous_locale_file.name)
      phraseapp_file  = phraseapp_files.fetch(previous_locale_file.name)

      previous_to_new_diffs       = Differ.calculate_diff(previous_locale_file.parsed_content, new_locale_file.parsed_content)
      previous_to_phraseapp_diffs = Differ.calculate_diff(previous_locale_file.parsed_content, phraseapp_file.parsed_content)

      resolved_diffs   = Differ.resolve_diffs(primary: previous_to_new_diffs, secondary: previous_to_phraseapp_diffs)
      resolved_content = Differ.apply_diffs(previous_locale_file.parsed_content, resolved_diffs)

      LocaleFile.from_hash(previous_locale_file.name, resolved_content)
    end

    resolved_files.each do |file|
      puts "Uploading #{file.inspect}"
      upload_id = phraseapp_api.upload_file(file)
      # What if the above succeeds and this fails? Bad state? Report it!
      # So much more logging
      # PhraseApp currently 500s with this valid request
      #phraseapp_api.remove_keys_not_in_upload(upload_id)
    end

  end
end

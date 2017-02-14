require 'phraseapp_updater/index_by'
require 'phraseapp_updater/differ'
require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/locale_file_loader'
require 'phraseapp_updater/phraseapp_api'

class PhraseAppUpdater
  using IndexBy

  def self.run(phraseapp_api_key, phraseapp_project_id, previous_locales_path, new_locales_path)
    phraseapp_api         = PhraseAppAPI.new(phraseapp_api_key, phraseapp_project_id)
    previous_locale_files = LocaleFileLoader.filenames(previous_locales_path).map { |l| LocaleFileLoader.load(l) }
    new_locale_files      = LocaleFileLoader.filenames(new_locales_path).map      { |l| LocaleFileLoader.load(l) }
    phraseapp_files       = phraseapp_api.download_all_locale_files

    file_name_lists = [previous_locale_files, new_locale_files, phraseapp_files].map do |files|
      files.map(&:name).to_set
    end

    # If we don't have the exact same locales for all three sources, we can't diff them
    unless file_name_lists[0] == file_name_lists[1] && file_name_lists[1] == file_name_lists[2]
      message = "Number of files differs. This tool does not yet support adding\
      or removing langauges: #{file_name_lists}"
      raise RuntimeError.new(message)
    end

    new_locale_files = new_locale_files.index_by(&:name)
    phraseapp_files  = phraseapp_files.index_by(&:name)

    resolved_files = previous_locale_files.map do |previous_locale_file|
      new_locale_file = new_locale_files.fetch(previous_locale_file.name)
      phraseapp_file  = phraseapp_files.fetch(previous_locale_file.name)

      resolved_content = Differ.resolve!(original: previous_locale_file.parsed_content,
                                         primary: new_locale_file.parsed_content,
                                         secondary: phraseapp_file.parsed_content)

      LocaleFile.from_hash(previous_locale_file.name, resolved_content)
    end

    changed_files = resolved_files.select do |file|
      file.parsed_content != phraseapp_files[file.name].parsed_content
    end

    upload_ids = phraseapp_api.upload_files(changed_files)
    phraseapp_api.remove_keys_not_in_uploads(upload_ids)

    LocaleFileUpdates.new(phraseapp_files.values, changed_files)
  end

  class LocaleFileUpdates
    attr_reader :original_phraseapp_files, :resolved_files

    def initialize(original_phraseapp_files, resolved_files)
      @original_phraseapp_files = original_phraseapp_files
      @resolved_files           = resolved_files
    end
  end
end


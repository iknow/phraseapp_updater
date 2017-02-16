require 'phraseapp_updater/version'
require 'phraseapp_updater/index_by'
require 'phraseapp_updater/differ'
require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/locale_file_loader'
require 'phraseapp_updater/phraseapp_api'
require 'phraseapp_updater/yml_config_loader'

class PhraseAppUpdater
  using IndexBy

  def self.push(phraseapp_api_key, phraseapp_project_id, previous_locales_path, new_locales_path)
    phraseapp_api         = PhraseAppAPI.new(phraseapp_api_key, phraseapp_project_id)
    phraseapp_locales     = phraseapp_api.download_locales

    phraseapp_files, (previous_locale_files, new_locale_files) =
      load_files(phraseapp_api, phraseapp_locales, false, previous_locales_path, new_locales_path)

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

    # Upload all of the secondary languages first,
    # so that the missing keys in them get filled in
    # with blanks on PhraseApp by the default locale.
    # If we do the clean up after uploading the default
    # locale file, these blanks will get cleaned because
    # they're not mentioned in the secondary locale files.

    default_locale_file = find_default_locale_file(phraseapp_locales, resolved_files)

    resolved_files.delete(default_locale_file)

    changed_files = resolved_files.select do |file|
      file.parsed_content != phraseapp_files[file.name].parsed_content
    end

    upload_ids = phraseapp_api.upload_files(changed_files)
    phraseapp_api.remove_keys_not_in_uploads(upload_ids)

    puts "Uploading #{default_locale_file}"
    upload_id = phraseapp_api.upload_file(default_locale_file)

    puts "Removing keys not in upload #{upload_id}"
    phraseapp_api.remove_keys_not_in_upload(upload_id)

    LocaleFileUpdates.new(phraseapp_files.values, [default_locale_file] + resolved_files)
  end

  def self.pull(phraseapp_api_key, phraseapp_project_id, fallback_locales_path)
    phraseapp_api         = PhraseAppAPI.new(phraseapp_api_key, phraseapp_project_id)
    phraseapp_locales     = phraseapp_api.download_locales

    phraseapp_files, (fallback_files,) =
      load_files(phraseapp_api, phraseapp_locales, true, fallback_locales_path)

    fallback_files = fallback_files.index_by(&:name)

    phraseapp_files.map do |phraseapp_file|
      new_content = Differ.restore_deletions(phraseapp_file.parsed_content,
                                             fallback_files[phraseapp_file.name].parsed_content)
      LocaleFile.from_hash(phraseapp_file.name, new_content)
    end
  end

  def self.load_config(config_file_path)
    YMLConfigLoader.new(config_file_path)
  end

  def self.find_default_locale_file(locales, files)
    default_locale = locales.find(&:default?)

    default_locale_file = files.find do |file|
      file.name == default_locale.name
    end
  end

  def self.load_files(phraseapp_api, phraseapp_locales, skip_unverified, *paths)
    file_groups = paths.map do |path|
       LocaleFileLoader.filenames(path).map { |l| LocaleFileLoader.load(l) }
    end

    phraseapp_files = phraseapp_api.download_files(phraseapp_locales, skip_unverified)

    file_name_lists = [*file_groups, phraseapp_files].map do |files|
      files.map(&:name).to_set
    end

    # If we don't have the exact same locales for all of the sources, we can't diff them
    unless file_name_lists.uniq.size == 1
      message = "Number of files differs. This tool does not yet support adding\
      or removing langauges: #{file_name_lists}"
      raise RuntimeError.new(message)
    end

    return [phraseapp_files, file_groups]
  end

  class LocaleFileUpdates
    attr_reader :original_phraseapp_files, :resolved_files

    def initialize(original_phraseapp_files, resolved_files)
      @original_phraseapp_files = original_phraseapp_files
      @resolved_files           = resolved_files
    end
  end
end


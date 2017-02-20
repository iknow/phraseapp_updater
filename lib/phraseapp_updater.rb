require 'phraseapp_updater/version'
require 'phraseapp_updater/index_by'
require 'phraseapp_updater/differ'
require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/locale_file_loader'
require 'phraseapp_updater/phraseapp_api'
require 'phraseapp_updater/yml_config_loader'

class PhraseAppUpdater
  using IndexBy

  def initialize(phraseapp_api_key, phraseapp_project_id)
    @phraseapp_api = PhraseAppAPI.new(phraseapp_api_key, phraseapp_project_id)
  end

  def self.load_config(config_file_path)
    YMLConfigLoader.new(config_file_path)
  end

  def push(previous_locales_path, new_locales_path)
    phraseapp_locales = @phraseapp_api.download_locales

    phraseapp_files = load_phraseapp_files(phraseapp_locales, false)

    (previous_locale_files, new_locale_files) =
      load_locale_files(previous_locales_path, new_locales_path)

    validate_files!([phraseapp_files, previous_locale_files, new_locale_files])

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

    upload_ids = @phraseapp_api.upload_files(changed_files)
    @phraseapp_api.remove_keys_not_in_uploads(upload_ids)

    puts "Uploading #{default_locale_file}"
    upload_id = @phraseapp_api.upload_file(default_locale_file)

    puts "Removing keys not in upload #{upload_id}"
    @phraseapp_api.remove_keys_not_in_upload(upload_id)

    LocaleFileUpdates.new(phraseapp_files.values, [default_locale_file] + resolved_files)
  end

  def pull(fallback_locales_path)
    phraseapp_locales = @phraseapp_api.download_locales

    phraseapp_files_without_unverified = load_phraseapp_files(phraseapp_locales, true)
    phraseapp_files_with_unverified    = load_phraseapp_files(phraseapp_locales, false)
    fallback_files                     = load_locale_files(fallback_locales_path).first

    validate_files!([phraseapp_files_with_unverified, phraseapp_files_without_unverified, fallback_files])

    phraseapp_files_with_unverified = phraseapp_files_with_unverified.index_by(&:name)
    fallback_files                  = fallback_files.index_by(&:name)

    # Clean empty strings from the data and merge the fallback data in:
    # we want to replace unverified keys with their values in the fallback
    phraseapp_files_without_unverified.map do |phraseapp_without_unverified_file|
      without_unverified = clear_empty_strings!(phraseapp_without_unverified_file.parsed_content)
      with_unverified    = clear_empty_strings!(phraseapp_files_with_unverified[phraseapp_without_unverified_file.name].parsed_content)
      fallback           = clear_empty_strings!(fallback_files[phraseapp_without_unverified_file.name].parsed_content)

      restore_unverified_originals!(fallback, with_unverified, without_unverified)
      LocaleFile.from_hash(phraseapp_without_unverified_file.name, without_unverified)
    end
  end

  private

  def find_default_locale_file(locales, files)
    default_locale = locales.find(&:default?)

    default_locale_file = files.find do |file|
      file.name == default_locale.name
    end
  end

  def load_phraseapp_files(phraseapp_locales, skip_unverified)
    @phraseapp_api.download_files(phraseapp_locales, skip_unverified)
  end

  def load_locale_files(*paths)
    paths.map do |path|
      LocaleFileLoader.filenames(path).map { |l| LocaleFileLoader.load(l) }
    end
  end

  def validate_files!(file_groups)
    file_name_lists = file_groups.map do |files|
      files.map(&:name).to_set
    end

    # If we don't have the exact same locales for all of the sources, we can't diff them
    unless file_name_lists.uniq.size == 1
      message = "Number of files differs. This tool does not yet support adding\
      or removing langauges: #{file_name_lists}"
      raise RuntimeError.new(message)
    end
  end

  # Mutates without_verified to include the fallbacks where needed.
  #
  # For any keys in both `with_unverified` and `originals` but not present in
  # `without_unverified`, restore the version from `originals` to
  # `without_unverified`
  def restore_unverified_originals!(fallback, with_unverified, without_unverified)
    fallback.each do |key, value|
      with_value = with_unverified[key]

      case value
      when Hash
        if with_value.is_a?(Hash)
          without_value = (without_unverified[key] ||= {})
          restore_unverified_originals!(value, with_value, without_value)
        end
      else
        if with_value && !with_value.is_a?(Hash) && !without_unverified.has_key?(key)
          without_unverified[key] = value
        end
      end
    end
  end

  def clear_empty_strings!(hash)
    hash.delete_if do |key, value|
      if value == ""
        true
      elsif value.is_a?(Hash)
        clear_empty_strings!(value)
        value.empty?
      else
        false
      end
    end
    hash
  end

  class LocaleFileUpdates
    attr_reader :original_phraseapp_files, :resolved_files

    def initialize(original_phraseapp_files, resolved_files)
      @original_phraseapp_files = original_phraseapp_files
      @resolved_files           = resolved_files
    end
  end
end


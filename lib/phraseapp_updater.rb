# frozen_string_literal: true

require 'phraseapp_updater/version'
require 'phraseapp_updater/index_by'
require 'phraseapp_updater/differ'
require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/phraseapp_api'
require 'phraseapp_updater/yml_config_loader'

class PhraseAppUpdater
  using IndexBy

  class SynchronizeError < RuntimeError
    attr_reader :status

    def initialize(status)
      super(status.to.s)
      @status = status
    end
  end

  def self.for_new_project(phraseapp_api_key, phraseapp_project_name, file_format, parent_commit, verbose: false)
    api = PhraseAppAPI.new(phraseapp_api_key, nil, LocaleFile.class_for_file_format(file_format))
    project_id = api.create_project(phraseapp_project_name, parent_commit)
    return self.new(phraseapp_api_key, project_id, file_format, verbose: verbose), project_id
  end

  def self.lookup_project(phraseapp_api_key, phraseapp_project_name)
    api = PhraseAppAPI.new(phraseapp_api_key, nil, nil)
    api.lookup_project_id(phraseapp_project_name)
  end

  def initialize(phraseapp_api_key, phraseapp_project_id, file_format, default_locale: 'en', verbose: false)
    @locale_file_class = LocaleFile.class_for_file_format(file_format)
    @default_locale    = default_locale
    @phraseapp_api     = PhraseAppAPI.new(phraseapp_api_key, phraseapp_project_id, @locale_file_class)
    @verbose           = verbose
  end

  def diff_directories(our_path, their_path)
    (our_locales, their_locales) = load_locale_directories(our_path, their_path)
    diff_locale_files(our_locales, their_locales)
  end

  def merge_directories(our_path, their_path, ancestor_path, result_path)
    (our_locales, their_locales, ancestor_locales) =
      load_locale_directories(our_path, their_path, ancestor_path)

    merged_locales = merge_locale_files(our_locales, their_locales, ancestor_locales)

    write_locale_directory(result_path, merged_locales)
  end

  def merge_files(ours, theirs, ancestor, result)
    our_file, their_file = load_locale_files(ours, theirs)
    # Read the ancestor if provided
    ancestor_file = load_locale_file(ancestor) unless ancestor.nil?

    result_file = merge_locale_files(our_file, their_file, ancestor_file)

    write_locale_file(result, result_file)
  end

  def upload_directory(path)
    locales = load_locale_directory(path)
    upload_locale_files(locales)
  end

  def download_to_directory(path)
    locale_files = download_locale_files
    write_locale_directory(path, locale_files)
  end

  def update_parent_commit(parent_commit)
    @phraseapp_api.update_parent_commit(parent_commit)
  end

  def read_parent_commit
    @phraseapp_api.read_parent_commit
  end

  def synchronize(checkout_path, locale_prefix, no_commit: false, branch: nil, remote: nil)
    Dir.chdir(checkout_path)
    branch ||= sh('git rev-parse --abbrev-ref HEAD').chomp
    remote ||= sh("git config branch.#{branch}.remote").chomp

    ENV['PHRASEAPP_API_KEY']    = @phraseapp_api.api_key
    ENV['PHRASEAPP_PROJECT_ID'] = @phraseapp_api.project_id
    ENV['FILE_FORMAT']          = @locale_file_class.extension
    ENV['PREFIX']               = locale_prefix
    ENV['NO_COMMIT']            = no_commit ? 't' : 'f'
    ENV['VERBOSE']              = @verbose   ? 't' : 'f'
    ENV['BRANCH']               = branch
    ENV['REMOTE']               = remote

    shell_script_path = File.join(__dir__, '..', 'bin', 'synchronize_phraseapp.sh')

    unless system(shell_script_path)
      raise SynchronizeError.new($?)
    end
  end

  end

  private

  def diff_locale_files(our_locales, their_locales)
    (our_content, their_content) = [our_locales, their_locales].map do |locales|
      locales.each_with_object({}) do |locale, h|
        h[locale.locale_name] = locale.parsed_content
      end
    end

    Hashdiff.diff(our_content, their_content)
  end

  def merge_locale_files(our_locales, their_locales, ancestor_locales)
    ours      = our_locales.index_by(&:locale_name)
    theirs    = their_locales.index_by(&:locale_name)
    ancestors = ancestor_locales.index_by(&:locale_name)

    locale_names = Set.new.merge(ours.keys).merge(theirs.keys)

    locale_names.map do |locale_name|
      STDERR.puts "Merging #{locale_name}" if @verbose
      our_file      = ours[locale_name]
      their_file    = theirs[locale_name]
      ancestor_file = ancestors[locale_name]
      merge_locale_file(our_file, their_file, ancestor_file)
    end
  end

  def upload_locale_files(locale_files)
    # We assert that the default locale contains all legitimate strings, and so
    # we clean up orphaned content on PhraseApp post-upload by removing keys not
    # in the default locale.
    default_locale_index = locale_files.find_index { |f| f.locale_name == @default_locale }
    raise RuntimeError.new("Missing default locale") unless default_locale_index

    upload_ids = @phraseapp_api.upload_files(locale_files, default_locale: @default_locale)
    default_upload_id = upload_ids[default_locale_index]

    STDERR.puts "Removing keys not in default locale upload #{default_upload_id}"
    @phraseapp_api.remove_keys_not_in_upload(default_upload_id)
  end

  def download_locale_files
    known_locales = @phraseapp_api.fetch_locales
    @phraseapp_api.download_files(known_locales, skip_unverified: false)
  end

  def merge_locale_file(our_file, their_file, ancestor_file)
    if our_file.nil?
      their_file
    elsif their_file.nil?
      our_file
    else
      ancestor_file ||= empty_locale_file(our_file.locale_name)

      resolved_content = Differ.new(verbose: @verbose).resolve!(
        original:  ancestor_file.parsed_content,
        primary:   our_file.parsed_content,
        secondary: their_file.parsed_content)

      @locale_file_class.from_hash(our_file.locale_name, resolved_content)
    end
  end

  def empty_locale_file(locale_name)
    @locale_file_class.from_hash(locale_name, {})
  end

  def load_locale_files(*filenames)
    filenames.map do |filename|
      load_locale_file(filename)
    end
  end

  def load_local_file(filename)
    @locale_file_class.load_file(filename)
  end

  def load_locale_directories(*paths)
    paths.map do |path|
      load_locale_directory(path)
    end
  end

  def load_locale_directory(path)
    @locale_file_class.load_directory(path)
  end

  def write_locale_file(path, locale_file)
    File.write(path, locale_file.content)
  end

  def write_locale_directory(path, locale_files)
    locale_files.each do |locale_file|
      full_path = File.join(path, locale_file.filename)
      File.write(full_path, locale_file.content)
    end
    STDERR.puts "Wrote #{locale_files.count} locale files to #{path}: #{locale_files.map(&:filename)}"
  end
end

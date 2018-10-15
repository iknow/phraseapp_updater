require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/index_by'
require 'phraseapp-ruby'
require 'thread'
require 'parallel'
require 'tempfile'

class PhraseAppUpdater
  using IndexBy
  class PhraseAppAPI
    def initialize(api_key, project_id, locale_file_class)
      @client            = PhraseApp::Client.new(PhraseApp::Auth::Credentials.new(token: api_key))
      @project_id        = project_id
      @locale_file_class = locale_file_class
    end

    def create_project(name)
      project = phraseapp_request do
        params = PhraseApp::RequestParams::ProjectParams.new(
          name: name,
          main_format: @locale_file_class.phraseapp_type,
        )
        @client.project_create(params)
      end
      STDERR.puts "Created project #{name}"
      @project_id = project.id
    end

    def fetch_locales
      # This is a paginated API, however the maximum page size of 100
      # is well above our expected locale size,
      # so we take the first page only for now
      phraseapp_request { @client.locales_list(@project_id, 1, 100) }.map do |pa_locale|
        Locale.new(pa_locale)
      end
    end

    def create_locale(name, default: false)
      phraseapp_request do
        params = PhraseApp::RequestParams::LocaleParams.new(
          name: name,
          code: name,
          default: default,
        )
        @client.locale_create(@project_id, params)
      end
    end

    def download_files(locales, skip_unverified:)
      results = threaded_request(locales) do |locale|
        STDERR.puts "Downloading file for #{locale}"
        download_file(locale, skip_unverified)
      end

      locales.zip(results).map do |locale, file_contents|
        @locale_file_class.from_file_content(locale.name, file_contents)
      end
    end

    def upload_files(locale_files, default_locale:)
      known_locales = fetch_locales.index_by(&:name)

      threaded_request(locale_files) do |locale_file|
        unless known_locales.has_key?(locale_file.locale_name)
          create_locale(locale_file.locale_name,
                        default: (locale_file.locale_name == default_locale))
        end

        STDERR.puts "Uploading #{locale_file}"
        upload_file(locale_file)
      end
    end

    def remove_keys_not_in_uploads(upload_ids)
      threaded_request(upload_ids) do |upload_id|
        STDERR.puts "Removing keys not in upload #{upload_id}"
        remove_keys_not_in_upload(upload_id)
      end
    end

    def download_file(locale, skip_unverified)
      download_params = PhraseApp::RequestParams::LocaleDownloadParams.new

      download_params.file_format                  = @locale_file_class.phraseapp_type
      download_params.skip_unverified_translations = skip_unverified

      phraseapp_request { @client.locale_download(@project_id, locale.id, download_params) }
    end

    def upload_file(locale_file)
      upload_params = create_upload_params(locale_file.locale_name)

      # The PhraseApp gem only accepts a filename to upload,
      # so we need to write the file out and pass it the path
      Tempfile.create([locale_file.locale_name, ".json"]) do |f|
        f.write(locale_file.content)
        f.close

        upload_params.file = f.path
        phraseapp_request { @client.upload_create(@project_id, upload_params) }.id
      end
    end

    def remove_keys_not_in_upload(upload_id)
      delete_params   = PhraseApp::RequestParams::KeysDeleteParams.new
      delete_params.q = "unmentioned_in_upload:#{upload_id}"

      begin
        phraseapp_request { @client.keys_delete(@project_id, delete_params) }
      rescue RuntimeError => _e
        # PhraseApp will accept but mark invalid uploads, however the gem
        # returns the same response in both cases. If we call this API
        # with the ID of an upload of a bad file, it will fail.
        # This usually occurs when sending up an empty file, which is
        # a case we can ignore. However, it'd be better to have a way
        # to detect a bad upload and find the cause.
      end
    end

    private

    def phraseapp_request(&block)
      res, err = block.call

      unless err.nil?
        error =
          if err.respond_to?(:error)
            err.error
          else
            err.errors.join("|")
          end

        raise RuntimeError.new(error)
      end

      res

    rescue RuntimeError => e
      if e.message.match?(/\(401\)/)
        raise BadAPIKeyError.new(e)
      elsif e.message.match?(/not found/)
        raise BadProjectIDError.new(e, @project_id)
      elsif e.message.match?(/has already been taken/)
        raise ProjectNameTakenError.new(e)
      else
        raise e
      end
    end

    # PhraseApp allows two concurrent connections at a time.
    THREAD_COUNT = 2

    def threaded_request(worklist, &block)
      Parallel.map(worklist, in_threads: THREAD_COUNT, &block)
    end

    def create_upload_params(locale_name)
      upload_params = PhraseApp::RequestParams::UploadParams.new
      upload_params.file_encoding       = "UTF-8"
      upload_params.file_format         = @locale_file_class.phraseapp_type
      upload_params.locale_id           = locale_name
      upload_params.skip_unverification = false
      upload_params.update_translations = true
      upload_params.tags                = [generate_upload_tag]
      upload_params
    end

    def generate_upload_tag
      "phraseapp_updater_upload_#{Time.now.strftime('%Y%m%d%H%M%S')}"
    end

    class Locale
      attr_reader :id, :name, :default
      def initialize(phraseapp_locale)
        @name    = phraseapp_locale.name
        @id      = phraseapp_locale.id
        @default = phraseapp_locale.default
      end

      def default?
        default
      end

      def to_s
        "#{name} : #{id}"
      end
    end

    class BadAPIKeyError < RuntimeError
      def initialize(original_error)
        super(original_error.message)
      end
    end

    class BadProjectIDError < RuntimeError
      attr_reader :project_id

      def initialize(original_error, id)
        @project_id = id
        super(original_error.message)
      end
    end

    class ProjectNameTakenError < RuntimeError
      def initialize(original_error)
        super(original_error.message)
      end
    end
  end
end

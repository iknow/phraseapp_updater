require 'phraseapp-ruby'
require 'phraseapp_updater/locale_file'
require 'thread'

class PhraseAppUpdater
  class PhraseAppAPI
    def initialize(api_key, project_id)
      @client     = PhraseApp::Client.new(PhraseApp::Auth::Credentials.new(token: api_key))
      @project_id = project_id
    end

    def download_locales
      # This is a paginated API, however the maximum page size of 100
      # is well above our expected locale size,
      # so we take the first page only for now
      phraseapp_request { @client.locales_list(@project_id, 1, 100) }.map do |pa_locale|
        Locale.new(pa_locale)
      end
    end

    def download_files(locales, skip_unverified)
      threaded_request(locales) do |locale|
        puts "Downloading file for #{locale}"
        download_file(locale, skip_unverified)
      end.map do |locale, file_contents|
        LocaleFile.new(locale.name, file_contents)
      end
    end

    def upload_files(locale_files)
      threaded_request(locale_files) do |locale_file|
        puts "Uploading #{locale_file}"
        upload_file(locale_file)
      end.map { |locale_file, upload_id | upload_id }
    end

    def remove_keys_not_in_uploads(upload_ids)
      threaded_request(upload_ids) do |upload_id|
        puts "Removing keys not in upload #{upload_id}"
        remove_keys_not_in_upload(upload_id)
      end
    end

    def download_file(locale, skip_unverified)
      download_params = PhraseApp::RequestParams::LocaleDownloadParams.new

      download_params.file_format                  = "nested_json"
      download_params.skip_unverified_translations = skip_unverified

      phraseapp_request { @client.locale_download(@project_id, locale.id, download_params) }
    end

    def upload_file(locale_file)
      upload_params = create_upload_params(locale_file.name)

      # The PhraseApp gem only accepts a filename to upload,
      # so we need to write the file out and pass it the path
      Tempfile.create(["#{locale_file.name}", ".json"]) do |f|
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
      rescue RuntimeError => e
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
        if err.respond_to?(:error)
          error = err.error
        else
          error = err.errors.join("|")
        end

        raise RuntimeError.new(error)
      end

      res
    end

    # PhraseApp allows two concurrent connections at a time.
    THREAD_COUNT = 2

    def threaded_request(worklist, &block)
      queue   = worklist.inject(Queue.new, :push)
      threads = []

      THREAD_COUNT.times do
        threads << Thread.new do
          Thread.current[:result] = {}

          begin
            while work = queue.pop(true) do
              Thread.current[:result][work] = block.call(work)
            end
          rescue ThreadError => e
            Thread.exit
          end

        end
      end

      threads.each(&:join)

      threads.each_with_object({}) do |thread, results|
        results.merge!(thread[:result])
      end
    end

    def create_upload_params(locale_name)
      upload_params = PhraseApp::RequestParams::UploadParams.new
      upload_params.file_encoding       = "UTF-8"
      upload_params.file_format         = "nested_json"
      upload_params.locale_id           = locale_name
      upload_params.skip_unverification = false
      upload_params.update_translations = true
      upload_params.tags                = [generate_upload_tag]
      upload_params
    end

    def generate_upload_tag
      "file_merge_upload_#{Time.now.strftime('%Y%m%d%H%M%S')}"
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
  end
end


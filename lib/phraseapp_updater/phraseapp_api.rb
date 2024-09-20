# frozen_string_literal: true

require 'phraseapp_updater/locale_file'
require 'phraseapp_updater/index_by'
require 'uri'
require 'phrase'
require 'parallel'
require 'tempfile'

class PhraseAppUpdater
  using IndexBy
  class PhraseAppAPI
    GIT_TAG_PREFIX = 'gitancestor_'
    PAGE_SIZE = 100

    def initialize(api_key, project_id, locale_file_class)
      config = Phrase::Configuration.new do |c|
        c.api_key['Authorization'] = api_key
        c.api_key_prefix['Authorization'] = 'token'
        c.debugging = false
      end

      @client            = Phrase::ApiClient.new(config)
      @project_id        = project_id
      @locale_file_class = locale_file_class
    end

    # @param [Hash] opts Options to be passed to the {https://developers.phrase.com/api/#post-/projects PhraseApp API}
    def create_project(name, parent_commit, **opts)
      params = Phrase::ProjectCreateParameters.new(
        # Merges name and main_format into opts to prevent overriding these properties
        opts.merge(
          name: name,
          main_format: @locale_file_class.phraseapp_type
        )
      )

      project = phraseapp_request(Phrase::ProjectsApi, :project_create, params)

      STDERR.puts "Created project #{name} for #{parent_commit}"

      @project_id = project.id
      store_parent_commit(parent_commit)

      project.id
    end

    def lookup_project_id(name)
      result, = paginated_request(Phrase::ProjectsApi, :projects_list, per_page: PAGE_SIZE, limit: 1) { |p| p.name == name }

      raise ProjectNotFoundError.new(name) if result.nil?

      result.id
    end

    # We mark projects with their parent git commit using a tag with a
    # well-known prefix. We only allow one tag with this prefix at once.
    def read_parent_commit
      git_tag, = paginated_request(Phrase::TagsApi, :tags_list, @project_id, limit: 1) do |t|
        t.name.start_with?(GIT_TAG_PREFIX)
      end

      raise MissingGitParentError.new if git_tag.nil?

      git_tag.name.delete_prefix(GIT_TAG_PREFIX)
    end

    def update_parent_commit(commit_hash)
      previous_parent = read_parent_commit
      phraseapp_request(Phrase::TagsApi, :tag_delete, @project_id, GIT_TAG_PREFIX + previous_parent)
      store_parent_commit(commit_hash)
    end

    def fetch_locales
      locales = paginated_request(Phrase::LocalesApi, :locales_list, @project_id)
      locales.map { |pa_locale| Locale.new(pa_locale) }
    end

    def create_locale(name, default: false)
      params = Phrase::LocaleCreateParameters.new(
        name: name,
        code: name,
        default: default,
      )
      phraseapp_request(Phrase::LocalesApi, :locale_create, @project_id, params)
    end

    def download_files(locales, skip_unverified:)
      results = threaded_request(locales) do |locale|
        STDERR.puts "Downloading file for #{locale}"
        download_locale(locale, skip_unverified)
      end

      locales.zip(results).map do |locale, file_contents|
        @locale_file_class.from_file_content(locale.name, file_contents)
      end
    end

    # Empirically, PhraseApp fails to parse the uploaded files when uploaded in
    # parallel. Give it a better chance by uploading them one at a time.
    def upload_files(locale_files, default_locale:)
      is_default = ->(l) { l.locale_name == default_locale }

      # Ensure the locales all exist
      STDERR.puts('Creating locales')
      known_locales = fetch_locales.index_by(&:name)
      threaded_request(locale_files) do |locale_file|
        unless known_locales.has_key?(locale_file.locale_name)
          create_locale(locale_file.locale_name, default: is_default.(locale_file))
        end
      end

      # Upload the files in a stable order, ensuring the default locale is first.
      locale_files.sort! do |a, b|
        next -1 if is_default.(a)
        next 1  if is_default.(b)

        a.locale_name <=> b.locale_name
      end

      uploads = {}

      uploads = locale_files.to_h do |locale_file|
        STDERR.puts("Uploading #{locale_file}")
        upload_id = upload_file(locale_file)
        [upload_id, locale_file]
      end

      # Validate the uploads, retrying failures as necessary
      successful_upload_ids = {}

      STDERR.puts('Verifying uploads...')
      until uploads.empty?
        threaded_request(uploads.to_a) do |upload_id, locale_file|
          upload = phraseapp_request(Phrase::UploadsApi, :upload_show, @project_id, upload_id)

          case upload.state
          when "enqueued", "processing"
            STDERR.puts("#{locale_file}: still processing")
          when "success"
            STDERR.puts("#{locale_file}: success")
            successful_upload_ids[locale_file.locale_name] = upload_id
            uploads.delete(upload_id)
          when "error"
            STDERR.puts("#{locale_file}: upload failure, retrying")
            new_upload_id = upload_file(locale_file)
            uploads.delete(upload_id)
            uploads[new_upload_id] = locale_file
          else
            raise RuntimeError.new("Unknown upload state: #{upload.state}")
          end
        end

        sleep(2) unless uploads.empty?
      end

      successful_upload_ids
    end

    def remove_keys_not_in_uploads(upload_ids)
      threaded_request(upload_ids) do |upload_id|
        STDERR.puts "Removing keys not in upload #{upload_id}"
        remove_keys_not_in_upload(upload_id)
      end
    end

    def download_locale(locale, skip_unverified)
      opts = {
        file_format: @locale_file_class.phraseapp_type,
        skip_unverified_translations: skip_unverified,
      }

      # Avoid allocating a tempfile (and emitting unnecessary warnings) by using `return_type` of `String`
      phraseapp_request(Phrase::LocalesApi, :locale_download, @project_id, locale.id, return_type: 'String', **opts)
    end

    def upload_file(locale_file)
      # The PhraseApp gem only accepts a filename to upload,
      # so we need to write the file out and pass it the path
      Tempfile.create([locale_file.locale_name, ".json"]) do |f|
        f.write(locale_file.content)
        f.close

        opts = {
          file:                 f,
          file_encoding:        'UTF-8',
          file_format:          @locale_file_class.phraseapp_type,
          locale_id:            locale_file.locale_name,
          skip_unverification:  false,
          update_translations:  true,
          tags:                 [generate_upload_tag],
        }

        result = phraseapp_request(Phrase::UploadsApi, :upload_create, @project_id, **opts)

        result.id
      end
    end

    def remove_keys_not_in_upload(upload_id)
      delete_pattern = "unmentioned_in_upload:#{upload_id}"
      phraseapp_request(Phrase::KeysApi, :keys_delete_collection, @project_id, q: delete_pattern)
    end

    private

    def store_parent_commit(commit_hash)
      params = Phrase::TagCreateParameters.new(name: GIT_TAG_PREFIX + commit_hash)
      phraseapp_request(Phrase::TagsApi,:tag_create, @project_id, params)
    end

    def wrap_phrase_errors
      yield
    rescue Phrase::ApiError => e
      if e.code == 401
        raise BadAPIKeyError.new(e)
      elsif e.message.match?(/not found/)
        raise BadProjectIDError.new(e, @project_id)
      elsif e.message.match?(/has already been taken/)
        raise ProjectNameTakenError.new(e)
      else
        raise
      end
    end

    def paginated_request(api_class, method, *params, limit: nil, **opts, &filter)

      api_instance = api_class.new(@client)
      page = 1
      results = []

      loop do
        response = wrap_phrase_errors do
          api_instance.public_send(method, *params, opts.merge(page: page, page_size: PAGE_SIZE))
        end

        break if response.data.empty?

        matches = response.data
        matches = matches.filter(&filter) if filter
        matches = matches[0, limit - results.size] if limit

        results.concat(matches) unless matches.empty?

        break if results.size == limit
        break unless response.next_page?

        page = response.next_page
      end

      results
    end

    def phraseapp_request(api_class, method, *params, **opts)
      api_instance = api_class.new(@client)

      response = wrap_phrase_errors do
        api_instance.public_send(method, *params, opts)
      end

      response.data
    end

    # PhraseApp allows two concurrent connections at a time.
    THREAD_COUNT = 2

    def threaded_request(worklist, &block)
      Parallel.map(worklist, in_threads: THREAD_COUNT, &block)
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

    class MissingGitParentError < RuntimeError
      def initialize
        super('Could not locate tag representing git ancestor commit')
      end
    end

    class ProjectNotFoundError < RuntimeError
      attr_reader :name

      def initialize(name)
        @name = name
        super("Project '#{name}' not found")
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

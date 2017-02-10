require 'phraseapp-ruby'
require_relative 'locale_file'

class PhraseAppAPI
  def initialize(api_key, project_id)
    @client     = PhraseApp::Client.new(PhraseApp::Auth::Credentials.new(token: api_key))
    @project_id = project_id
  end

  def all_locale_files
    locales = download_locales.map { |l| Locale.new(l) }

    locales.map do |l|
      LocaleFile.new(l.name, download_file(l))
    end
  end

  def download_locales
    # This is a paginated API, however the maximum page size of 100
    # is well above our expected locale size,
    # so we take the first page only for now
    phraseapp_request { @client.locales_list(@project_id, 1, 100) }
  end

  def download_file(locale)
    download_params = PhraseApp::RequestParams::LocaleDownloadParams.new

    download_params.file_format                  = "nested_json"
    download_params.skip_unverified_translations = false

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
    delete_params.q = "unmentioned_in_upload:\"#{upload_id}\""

    phraseapp_request { @client.keys_delete(@project_id, delete_params) }
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
    attr_reader :id, :name
    def initialize(phraseapp_locale)
      @name = phraseapp_locale.name
      @id   = phraseapp_locale.id
    end
  end
end

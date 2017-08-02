require 'spec_helper'
require 'phraseapp_updater/locale_file'

describe PhraseAppUpdater::LocaleFile do
  it "returns the right class for each extension" do
    expect(PhraseAppUpdater::LocaleFile.class_for_file_format("json")).to eq PhraseAppUpdater::LocaleFile::JSONFile
    expect(PhraseAppUpdater::LocaleFile.class_for_file_format("yml")).to  eq PhraseAppUpdater::LocaleFile::YAMLFile
    expect(PhraseAppUpdater::LocaleFile.class_for_file_format("yaml")).to eq PhraseAppUpdater::LocaleFile::YAMLFile
  end

  it "raises an error on unknown extensions" do
    expect { PhraseAppUpdater::LocaleFile.class_for_file_format("revx") }.to raise_error(PhraseAppUpdater::LocaleFile::BadFileTypeError)
  end
end

require 'spec_helper'
require 'phraseapp_updater/locale_file/json_file'

describe PhraseAppUpdater::LocaleFile::JSONFile do
  let(:locale_file) { PhraseAppUpdater::LocaleFile::JSONFile.from_file_content(@name, @content) }
  before do
    @name    = 'ja'
    @content = "{}\n"
  end

  it 'returns its name' do
    expect(locale_file.name).to eq @name
  end

  it 'returns its name with an extension' do
    expect(locale_file.name_with_extension).to eq "#{@name}.json"
  end

  it 'parses proper JSON' do
    @content = '{"a": {"c": 10, "b": 5}}'
    expect(locale_file.parsed_content).to eq({ "a" => { "b" => 5, "c" => 10 } })
  end

  it 'exposes its content' do
    expect(locale_file.content).to eq "{}\n"
  end

  it 'returns an error when passed bad JSON' do
    @content = '{"a:}'
    expect { locale_file }.to raise_error(ArgumentError)
  end

  it 'returns a string representation' do
    expect(locale_file.to_s).to eq "ja"
  end

  it 'can be initialized from a hash' do
    file = PhraseAppUpdater::LocaleFile::JSONFile.from_hash('en', { a: { c: 10, b: 5 } })
    expect(file.content).to eq(<<-JSON)
{
  "a":{
    "b":5,
    "c":10
  }
}
    JSON

    expect(file.parsed_content).to eq({ "a" => { "b" => 5, "c" => 10 } })
  end
end

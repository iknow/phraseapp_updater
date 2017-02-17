require 'spec_helper'
require 'phraseapp_updater/locale_file'

describe PhraseAppUpdater::LocaleFile do
  let(:locale_file) { PhraseAppUpdater::LocaleFile.new(@name, @content) }
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
    @content = '{"a": {"b": 5}}'
    expect(locale_file.parsed_content).to eq({"a" => {"b" => 5}})
  end

  it 'exposes its content' do
    expect(locale_file.content).to eq "{}\n"
  end

  it 'returns an error when passed bad JSON' do
    @content = '{"a:}'
    expect { locale_file }.to raise_error(ArgumentError)
  end

  it 'returns a string representation' do
    expect(locale_file.to_s).to eq "ja, {}\n..."
  end

  it 'can be initialized from a hash' do
    file = PhraseAppUpdater::LocaleFile.from_hash('en', {a: 5})
    expect(file.content).to eq "{\n  \"a\":5\n}\n"
    expect(file.parsed_content).to eq({"a" => 5})
  end
end

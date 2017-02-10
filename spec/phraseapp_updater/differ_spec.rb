require 'spec_helper'
require 'phraseapp_updater/differ'

describe Differ do
  subject { Differ.resolve!(original: original, primary: a, secondary: b) }

  context 'simple diffs' do
    let(:original) { {} }
    let(:a) { {"a" => 4} }
    let(:b) { {"b" => 5} }

    it 'resolves simple diffs' do
      expect(subject).to eq({"a" => 4, "b" => 5})
    end
  end
end

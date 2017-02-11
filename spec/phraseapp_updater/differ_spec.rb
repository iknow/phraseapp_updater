require 'spec_helper'
require 'phraseapp_updater/differ'

describe Differ do
  subject { Differ.resolve!(original: original, primary: @a, secondary: @b) }

  context 'empty base' do
    let(:original) { {} }

    context 'non-conflicting diffs' do

      it 'resolves simple diffs' do
        @a = {"a" => 4}
        @b = {"b" => 5}
        expect(subject).to eq({"a" => 4, "b" => 5})
      end

      it 'adds keys to an existing hash' do
      end
    end
  end
end

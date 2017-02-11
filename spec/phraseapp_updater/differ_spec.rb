require 'spec_helper'
require 'phraseapp_updater/differ'

describe Differ do
  subject { Differ.resolve!(original: original, primary: @a, secondary: @b) }

  context 'empty base' do
    let(:original) { {} }

    it 'resolves non-conflicing additions' do
      @a = {"a" => 1}
      @b = {"b" => 2}
      expect(subject).to eq({"a" => 1, "b" => 2})
    end

    it 'resolves a change on a shallow key by taking the primary side' do
      @a = {"a" => 1}
      @b = {"a" => 2}
      expect(subject).to eq({"a" => 1})
    end

    it 'resolves non-conflicting changes to a nested key' do
      @a = {"a" => {"c" => 1}}
      @b = {"a" => {"b" => 2}}
      expect(subject).to eq({"a" => {"b" => 2, "c" => 1}})
    end
  end

  context 'shallow base' do
    let(:original) { {"a" => 1, "b" => 2, "c" => 3} }

    it 'resolves non-conflicing additions' do
      @a = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}
      @b = {"a" => 1, "b" => 2, "c" => 3, "e" => 5}
      expect(subject).to eq({"a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5})
    end

    it 'resolves a change on a shallow key by taking the primary side' do
      @a = {"a" => 1, "b" => 2, "c" => 4}
      @b = {"a" => 1, "b" => 2, "c" => 5}
      expect(subject).to eq({"a" => 1, "b" => 2, "c" => 4})
    end

    context 'shallow deletion on a' do
      before { @a = {"a" => 1, "b" => 2} }

      it 'resolves to the deletion when b makes a shallow change' do
        @b = {"a" => 1, "b" => 2, "c" => 5}
        expect(subject).to eq({"a" => 1, "b" => 2})
      end

      it 'resolves to the deletion when b also deletes it' do
        @b = {"a" => 1, "b" => 2, "d" => 4}
        expect(subject).to eq({"a" => 1, "b" => 2, "d" => 4})
      end

      it 'resolves to the deletion when b makes it a nested key' do
        @b = {"a" => 1, "b" => 2, "c" => {"d" => 3}}
        expect(subject).to eq({"a" => 1, "b" => 2})
      end
    end
  end
end

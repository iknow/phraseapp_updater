require 'spec_helper'
require 'phraseapp_updater/differ'

describe PhraseAppUpdater::Differ do
  let(:resolution) { Differ.resolve!(original: original, primary: @a, secondary: @b) }

  context 'empty base' do
    let(:original) { {} }

    it 'resolves non-conflicing additions' do
      @a = {"a" => 1}
      @b = {"b" => 2}
      expect(resolution).to eq({"a" => 1, "b" => 2})
    end

    it 'resolves a change on a shallow key by taking the primary side' do
      @a = {"a" => 1}
      @b = {"a" => 2}
      expect(resolution).to eq({"a" => 1})
    end

    it 'resolves non-conflicting changes to a nested key' do
      @a = {"a" => {"c" => 1}}
      @b = {"a" => {"b" => 2}}
      expect(resolution).to eq({"a" => {"b" => 2, "c" => 1}})
    end
  end

  context 'shallow base' do
    let(:original) { {"a" => 1, "b" => 2, "c" => 3} }

    it 'resolves non-conflicing additions' do
      @a = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}
      @b = {"a" => 1, "b" => 2, "c" => 3, "e" => 5}
      expect(resolution).to eq({"a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5})
    end

    it 'resolves a change on a shallow key by taking the primary side' do
      @a = {"a" => 1, "b" => 2, "c" => 4}
      @b = {"a" => 1, "b" => 2, "c" => 5}
      expect(resolution).to eq({"a" => 1, "b" => 2, "c" => 4})
    end

    it 'resolves change in type in secondary' do
      @a = original.merge("a" => 10)
      @b = original.merge("a" => { "z" => 1})

      expect(resolution).to eq({"a" => 10, "b" => 2, "c" => 3})
    end

    it 'resolves change in type in primary' do
      @a = original.merge("a" => { "z" => 1})
      @b = original.merge("a" => 10)

      expect(resolution).to eq({"a" => { "z" => 1 }, "b" => 2, "c" => 3})
    end

    it 'handles hash addition overriding terminal addition' do
      @a = original.merge("d" => { "z" => 1 })
      @b = original.merge("d" => 10)

      expect(resolution).to eq({"a" => 1, "b" => 2, "c" => 3, "d" => { "z" => 1 }})
    end

    it 'handles terminal addition overriding hash addition' do
      @a = original.merge("d" => 10)
      @b = original.merge("d" => { "z" => 1 })

      expect(resolution).to eq({"a" => 1, "b" => 2, "c" => 3, "d" => 10})
    end

    context 'shallow deletion on a' do
      before { @a = {"a" => 1, "b" => 2} }

      it 'resolves to the deletion when b makes a shallow change' do
        @b = {"a" => 1, "b" => 2, "c" => 5}
        expect(resolution).to eq({"a" => 1, "b" => 2})
      end

      it 'resolves to the deletion when b also deletes it' do
        @b = {"a" => 1, "b" => 2, "d" => 4}
        expect(resolution).to eq({"a" => 1, "b" => 2, "d" => 4})
      end

      it 'resolves to the deletion when b makes it a nested key' do
        @b = {"a" => 1, "b" => 2, "c" => {"d" => 3}}
        expect(resolution).to eq({"a" => 1, "b" => 2})
      end

      it 'resolves to the deletion when b makes it a multi-nested key' do
        @b = {"a" => 1, "b" => 2, "c" => {"d" => {"e" => 5}}}
        expect(resolution).to eq({"a" => 1, "b" => 2})
      end
    end

    context 'nested deletion on a' do
      before { @a = {"a" => 1, "b" => 2} }
    end
  end

  context 'nested_base' do
    let(:original) { {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3 }}} }

    it 'handles changing hash to terminal overriding editing a hash' do
      @a = original.merge("b" => 10)
      @b = { "a" => 1, "b" => { "q" => 5 }}
      expect(resolution).to eq({ "a" => 1, "b" => 10 })
    end

    it "handles mutating a hash overriding changing a terminal" do
      @a = { "a" => 1, "b" => { "q" => 5 }}
      @b = original.merge("b" => 10)
      expect(resolution).to eq({ "a" => 1, "b" => { "q" => 5 } })
    end

    it "handles mutating a child of a hash overriding changing parent to a terminal" do
      @a = { "a" => 1, "b" => { "c" => 2, "d" => { "q" => 5 }}}
      @b = original.merge("b" => 10)
      expect(resolution).to eq(@a)
    end

    it "handles deleting a child overriding editing a hash" do
      @a = {"a" => 1, "b" => {"c" => 2}}
      @b = {"a" => 1, "b" => {"c" => 2, "d" => {"e" => 4}}}
      expect(resolution).to eq(@a)
    end

    it "handles deleting a child overriding editing a hash" do
      @a = {"a" => 1, "b" => {"c" => 2}}
      @b = {"a" => 1, "b" => {"c" => 2, "d" => {"e" => 4}}}
      expect(resolution).to eq(@a)
    end

    it "handles mututally adding to a nested key" do
      @a =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => 4 }}}
      @b =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "g" => 5 }}}
      expect(resolution).to eq({"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => 4, "g" => 5 }}})
    end

    it "handles adding a nested key against making the parent a terminal" do
      @a =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => 4 }}}
      @b =  {"a" => 1, "b" => { "c" => 2, "d" => 5}}
      expect(resolution).to eq({"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => 4}}})
    end

    it "handles adding a nested key as a terminal against adding it as a hash" do
      @a =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => 4 }}}
      @b =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => {"g" => 5}}}}
      expect(resolution).to eq({"a" => 1, "b" => { "c" => 2, "d" => { "e" => 3, "f" => 4}}})
    end

    it "handles concurrent editing of a nested terminal" do
      @a =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 6}}}
      @b =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 7}}}
      expect(resolution).to eq({"a" => 1, "b" => { "c" => 2, "d" => { "e" => 6}}})
    end

    it "handles editing a nested terminal versus deletion" do
      @a =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 6}}}
      @b =  {"a" => 1, "b" => { "c" => 2, "d" => { "f" => 7}}}
      expect(resolution).to eq({"a" => 1, "b" => { "c" => 2, "d" => { "e" => 6, "f" => 7}}})
    end

    it "handles editing a nested terminal versus deletion of the parent" do
      @a =  {"a" => 1, "b" => { "c" => 2, "d" => { "e" => 6}}}
      @b =  {"a" => 1, "b" => { "c" => 2, }}
      expect(resolution).to eq({"a" => 1, "b" => { "c" => 2, "d" => { "e" => 6}}})
    end
  end
end


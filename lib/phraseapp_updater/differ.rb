require 'set'
require 'hashdiff'

module StringIndicies
  refine String do
    def all_indicies(sub_string)
      i = -1
      indicies = []
      while i = self.index(sub_string, i + 1)
        indicies << i
      end
      indicies
    end
  end
end

class Differ
  # The indicies for the diff arrays
  # that HashDiff returns
  CHANGE = 0
  KEY    = 1
  VALUE  = 2

  using StringIndicies
  class << self
    def calculate_diff(a, b)
      HashDiff.diff(flatten(a), flatten(b))
    end

    # Resolution strategy is that primary always wins in the event of a conflict
    def resolve_diffs(primary:, secondary:)
      conflicts = (primary.map { |a| a[KEY] }.to_set) & (secondary.map { |a| a[KEY] }.to_set)
      secondary.delete_if { |type, key, old, new| conflicts.include?(key) }

      # Since our resolution strategy is that primary always wins, we want to discard
      # any changes or additions to keys in secondary which are deleted in primary.
      # For shallow keys, this is unnecessary, as the above resolution will have
      # filtered them already. However, consider the following case:
      #
      # primary   = [["-", "a", 3]]
      # secondary = [["+", "a.b", 5]]
      #
      # The above resolution will leave both of these diffs in tact. However,
      # when HashDiff goes to apply them, it will first remove a from original
      # and then attempt to perform `original["a"]["b"] = 5`, which is an error.
      #
      # So we add another resolution step: gather all the keys that primary deletes
      # and then kill any children of those keys in secondary. This is a nested
      # extension of the above resolution strategy of primary winning.

      deletions = primary.select { |diff| diff[CHANGE] == "-" }.map! { |diff| diff[KEY] }
      secondary.delete_if { |diff| deletions.any? { |deletion| diff[KEY].start_with?(deletion) } }

      primary + secondary
    end

    def apply_diffs(hash, diffs)
      deep_compact!(HashDiff.patch!(hash, diffs))
    end

    def resolve!(original:, primary:, secondary:)
      primary_diffs   = Differ.calculate_diff(original, primary)
      secondary_diffs = Differ.calculate_diff(original, secondary)

      resolved_diffs   = Differ.resolve_diffs(primary: primary_diffs, secondary: secondary_diffs)
      new_nested_diffs = create_nested_key_diffs(original, calculate_added_nested_keys(resolved_diffs))

      Differ.apply_diffs(original, new_nested_diffs + resolved_diffs)
    end

    private

    def calculate_added_nested_keys(diffs, depth = 1)
      keys = diffs.map { |d| d[KEY] }.select { |key| key.count(".") == depth }
      return [] if keys.empty?

      keys.map! do |key|
        nested_index = key.all_indicies(".")[depth - 1]
        key[0, nested_index]
      end

      return (keys + calculate_added_nested_keys(diffs, depth + 1))
    end

    # For each nested key in the diffs, check if they
    # are not present in the base. If not present,
    # create a diff that first adds the key
    def create_nested_key_diffs(original, new_nested_keys)
      needed_keys = Set.new

      new_nested_keys.select do |nested_key|
        # Traverse the original to see if we have the key
        # If we hit a KeyError, this is a key we need to add.
        current_hash = original
        current_key  = nil

        begin
          nested_key.split(".").each do |key|
            current_key  = key
            current_hash = current_hash.fetch(current_key)
          end
        rescue KeyError => e
          needed_keys.add(current_key)
        end

      end

      needed_keys.map do |key|
        ["+", key, {}]
      end
    end

    def flatten(hash, prefix = nil, acc = {})
      hash.each do |k, v|
        k = "#{prefix}.#{k}" if prefix
        if v.is_a?(Hash)
          flatten(v, k, acc)
        else
          acc[k] = v
        end
      end
      acc
    end

    def deep_compact!(hash)
      hash.delete_if do |k, v|
        if v.is_a?(Hash)
          deep_compact!(v).empty?
        else
          v.nil?
        end
      end
    end
  end

end


require 'set'
require 'hashdiff'

class Differ
  class << self
    def calculate_diff(a, b)
      HashDiff.diff(flatten(a), flatten(b))
    end

    # Resolution strategy is that primary always wins
    # in the event of a conflict
    def resolve_diffs(primary:, secondary:)
      conflicts = (primary.map { |a| a[1] }.to_set) & (secondary.map { |a| a[1] }.to_set)
      secondary.delete_if { |type, key, old, new| conflicts.include?(key) }
      primary + secondary
    end

    def apply_diffs(hash, diffs)
      deep_compact!(HashDiff.patch!(hash, diffs))
    end

    private

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

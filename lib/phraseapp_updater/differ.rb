require 'set'
require 'hashdiff'
require 'deep_merge'

class PhraseAppUpdater
  class Differ
    SEPARATOR = "~~~"
    using IndexBy

    class << self
      # Resolution strategy is that primary always wins in the event of a conflict
      def resolve_diffs(primary:, secondary:, secondary_deleted_prefixes:)
        primary   = primary.index_by   { |op, path, from, to| path }
        secondary = secondary.index_by { |op, path, from, to| path }

        # As well as explicit conflicts, we want to make sure that deletions or
        # incompatible type changes to a `primary` key prevent addition of child
        # keys in `secondary`. Because input hashes are flattened, it's never
        # possible for a given path and its prefix to be in the same input.
        # For example, in:
        #
        # primary   = [["+", "a", 1]]
        # secondary = [["+", "a.b", 2]]
        #
        # the secondary change is impossible to perform on top of the primary, and
        # must be blocked.
        #
        # This applies in reverse: prefixes of paths in `p` need to be available
        # as hashes, so must not appear as terminals in `s`:
        #
        # primary   = [["+", "a.b", 2]]
        # secondary = [["+", "a",   1]]
        primary_prefixes = primary.keys.flat_map { |p| path_prefixes(p) }.to_set

        # Remove conflicting entries from secondary, recording incompatible
        # changes.
        path_conflicts = []
        secondary.delete_if do |path, diff|
          if primary_prefixes.include?(path) || primary.keys.any? { |pk| path.start_with?(pk) }
            path_conflicts << path unless primary.has_key?(path) && diff == primary[path]
            true
          else
            false
          end
        end

        # For all path conflicts matching secondary_deleted_prefixes, additionally
        # remove other changes with the same prefix.
        prefix_conflicts = secondary_deleted_prefixes.select do |prefix|
          path_conflicts.any? { |path| path.start_with?(prefix) }
        end

        secondary.delete_if do |path, diff|
          prefix_conflicts.any? { |prefix| path.start_with?(prefix) }
        end

        primary.values + secondary.values
      end

      def apply_diffs(hash, diffs)
        deep_compact!(HashDiff.patch!(hash, diffs))
      end

      def resolve!(original:, primary:, secondary:)
        # To appropriately cope with type changes on either sides, flatten the
        # trees before calculating the difference and then expand afterwards.
        f_original  = flatten(original)
        f_primary   = flatten(primary)
        f_secondary = flatten(secondary)

        primary_diffs   = HashDiff.diff(f_original, f_primary)
        secondary_diffs = HashDiff.diff(f_original, f_secondary)

        # However, flattening discards one critical piece of information: when we
        # have deleted or clobbered an entire prefix (subtree) from the original,
        # we want to consider this deletion atomic. If any of the changes is
        # cancelled, they must all be. Motivating example:
        #
        # original:  { word: { one: "..", "many": ".." } }
        # primary:   { word: { one: "..", "many": "..", "zero": ".." } }
        # secondary: { word: ".." }
        # would unexpectedly result in { word: { zero: ".." } }.
        #
        # Additionally calculate subtree prefixes that were deleted in `secondary`:
        secondary_deleted_prefixes =
          HashDiff.diff(original, secondary, delimiter: SEPARATOR).lazy
          .select { |op, path, from, to| (op == "-" || op == "~") && from.is_a?(Hash) && !to.is_a?(Hash) }
          .map    { |op, path, from, to| path }
          .to_a


        resolved_diffs = resolve_diffs(primary:   primary_diffs,
                                       secondary: secondary_diffs,
                                       secondary_deleted_prefixes: secondary_deleted_prefixes)
        HashDiff.patch!(f_original, resolved_diffs)

        expand(f_original)
      end


      # Prefer everything in current except deletions,
      # which are restored from previous if available
      def restore_deletions(current, previous)
        current.deep_merge(previous)
      end

      private

      def flatten(hash, prefix = nil, acc = {})
        hash.each do |k, v|
          k = "#{prefix}#{SEPARATOR}#{k}" if prefix
          if v.is_a?(Hash)
            flatten(v, k, acc)
          else
            acc[k] = v
          end
        end
        acc
      end

      def expand(flat_hash)
        flat_hash.each_with_object({}) do |(key, value), root|
          path = key.split(SEPARATOR)
          leaf_key = path.pop
          leaf = path.inject(root) do |node, path_key|
            node[path_key] ||= {}
          end
          raise ArgumentError.new("Type conflict in flattened hash expand: expected no key at #{key}") if leaf.has_key?(leaf_key)
          leaf[leaf_key] = value
        end
      end

      def path_prefixes(path_string)
        path = path_string.split(SEPARATOR)
        parents = []
        path.inject do |acc, el|
          parents << acc
          "#{acc}#{SEPARATOR}#{el}"
        end
        parents
      end
    end
  end
end


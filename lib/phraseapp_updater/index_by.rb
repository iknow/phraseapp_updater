class PhraseAppUpdater
  module IndexBy
    refine Array do
      def index_by(&block)
        each_with_object({}) do |value, hash|
          hash[yield(value)] = value
        end
      end
    end
  end
end

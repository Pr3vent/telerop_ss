# frozen_string_literal: true

require "yaml"

module TeleropSs
  # A loaded, immutable rule set: the point table for each category, the score cap, and the
  # version string that gets stamped onto every score computed with it.
  #
  # Rule sets are versioned files shipped inside the gem (lib/telerop_ss/rules/*.yml) so that a
  # score persisted last year can still be reproduced after the table changes: keep the old file,
  # add a new one, and callers ask for the version they want. Nothing outside this class reads
  # YAML, so an app can also supply its own file via Rules.load_file for a pilot table.
  class Rules
    DIR = File.expand_path("rules", __dir__)
    DEFAULT_VERSION = "telerop_ss_v1"

    class UnknownRuleSet < ArgumentError; end

    class << self
      # Fetch (and memoize) a rule set shipped with the gem, by version name.
      def fetch(version = DEFAULT_VERSION)
        version = version.to_s
        cache[version] ||= load_file(path_for(version))
      end

      # Load a rule set from an arbitrary path. Not memoized — callers that want caching should
      # hold on to the returned object.
      def load_file(path)
        raise UnknownRuleSet, "no rule set at #{path}" unless File.file?(path)

        new(YAML.safe_load(File.read(path), aliases: false) || {})
      end

      # Version names of every rule set shipped with the gem.
      def available_versions
        Dir.children(DIR).grep(/\.yml\z/).map { |f| File.basename(f, ".yml") }.sort
      end

      # Drop memoized rule sets. Only useful in tests, or when editing a rule file in place.
      def reset!
        @cache = nil
      end

      private

      def cache
        @cache ||= {}
      end

      def path_for(version)
        path = File.join(DIR, "#{version}.yml")
        unless File.file?(path)
          raise UnknownRuleSet,
                "unknown rule set #{version.inspect}; available: #{available_versions.join(', ')}"
        end

        path
      end
    end

    attr_reader :version, :cap

    def initialize(raw)
      @version = raw["version"].to_s
      raise ArgumentError, "rule set is missing a version" if @version.empty?

      @cap = raw["cap"]&.to_i

      # Normalize once at load: categories and values are matched upcased, points as integers.
      @categories = (raw["categories"] || {}).each_with_object({}) do |(category, values), out|
        out[category.to_s.upcase] = (values || {}).each_with_object({}) do |(value, points), table|
          table[value.to_s.upcase] = points.to_i
        end
      end
      freeze
    end

    # Points for a value within a category, or nil when the category does not list that value
    # (an unrecognized grade scores nothing rather than zero, so it stays out of the breakdown).
    def points_for(category, value)
      @categories.fetch(category.to_s.upcase, nil)&.fetch(value.to_s.upcase, nil)
    end

    # All values listed for a category, upcased. Handy for host-app validation of grade options.
    def values_for(category)
      @categories.fetch(category.to_s.upcase, {}).keys
    end

    def categories
      @categories.keys
    end

    def freeze
      @categories.each_value(&:freeze)
      @categories.freeze
      super
    end
  end
end

# frozen_string_literal: true

module TeleropSs
  # Adapter over whatever the host app calls an "annotation state" — normally the eye record
  # itself — so the scorer never has to care which shape it was handed.
  #
  # An object is used directly when it responds to the reader methods below; anything else is
  # treated as a plain Hash of code => value, which keeps the gem usable from scripts, fixtures
  # and tests without dragging in the host's models.
  #
  #   Eye-level (required):
  #     annotation_value(code)    -> String or nil   the graded value for a code
  #     annotation_present?(code) -> true/false      for presence-only booleans (e.g. "arop")
  #
  #   Image-level (optional; used only to fall back when the eye-level value is blank):
  #     image_level_values_for(code) -> Array<String>  genuine per-image values, no eye fallback
  #     image_level_present?(code)   -> true/false     boolean present on any image
  class State
    TRUTHY = ["1", "t", "true", "y", "yes", "on"].freeze

    def self.wrap(source)
      source.is_a?(State) ? source : new(source)
    end

    def initialize(source)
      @source = source
    end

    def value(code)
      raw =
        if @source.respond_to?(:annotation_value)
          @source.annotation_value(code)
        elsif @source.respond_to?(:[])
          @source[code.to_s] || @source[code.to_sym]
        end

      presence(raw)
    end

    def present?(code)
      if @source.respond_to?(:annotation_present?)
        !!@source.annotation_present?(code)
      elsif @source.respond_to?(:[])
        truthy?(@source[code.to_s] || @source[code.to_sym])
      else
        false
      end
    end

    # Per-image values for a code, already split out of any comma-joined multi-selects.
    def image_values(code)
      return [] unless @source.respond_to?(:image_level_values_for)

      expand(@source.image_level_values_for(code))
    end

    def image_present?(code)
      return false unless @source.respond_to?(:image_level_present?)

      !!@source.image_level_present?(code)
    end

    # Split comma-joined multi-select values into their individual members.
    def expand(values)
      Array(values).flat_map { |v| v.to_s.split(",") }.filter_map { |v| presence(v.strip) }
    end

    private

    def presence(raw)
      str = raw.to_s
      str.strip.empty? ? nil : str
    end

    def truthy?(raw)
      case raw
      when true then true
      when false, nil then false
      when Numeric then !raw.zero?
      else TRUTHY.include?(raw.to_s.strip.downcase)
      end
    end
  end
end

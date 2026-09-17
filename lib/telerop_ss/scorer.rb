# frozen_string_literal: true

require "telerop_ss/rules"
require "telerop_ss/state"

module TeleropSs
  # Computes the TeleROP severity score for one eye from its annotation state.
  #
  # The scoring policy lives here; the point values live in a versioned rule file (see Rules).
  # The result is a plain Hash so it can be persisted, compared and serialized by the host app
  # without depending on gem classes:
  #
  #   { raw_total:, final_total:, components: [{category:, value:, points:}], modifiers: [],
  #     rules_version: }
  class Scorer
    def self.call(annotation_state, rules: Rules::DEFAULT_VERSION)
      new(annotation_state, rules: rules).call
    end

    def initialize(annotation_state, rules: Rules::DEFAULT_VERSION)
      @state = State.wrap(annotation_state)
      @rules = rules.is_a?(Rules) ? rules : Rules.fetch(rules)
      @components = []
    end

    def call
      # AROP is terminal: an eye graded AROP scores its points outright and the other
      # components are not evaluated at all, so the score is the same regardless of the
      # zone/stage/plus recorded alongside it.
      if arop_value
        score_component("AROP", arop_value)
      else
        score_component("ZONE", zone_value)
        score_component("STAGE", stage_value)
        score_component("PLUS", plus_value)
      end

      raw_total = @components.sum { |c| c[:points] }

      {
        raw_total: raw_total,
        final_total: apply_cap(raw_total),
        components: @components,
        modifiers: [],
        rules_version: @rules.version
      }
    end

    private

    def score_component(category, raw_value)
      return if raw_value.nil? || raw_value.to_s.strip.empty?

      category = category.to_s.upcase
      value = raw_value.to_s.upcase
      points = @rules.points_for(category, value)
      return if points.nil?

      @components << { category: category, value: value, points: points }
    end

    def zone_value
      @state.value("zone") || worst_image_value("ZONE", "zone")
    end

    def stage_value
      return "REGRESS-LASER" if @state.present?("regression_after_laser")
      return "REGRESS-VEGFI" if @state.present?("regression_par_after_anti_vegf")
      return "REGRESS" if @state.present?("regression_spontaneous")

      # Stage is multi-select (comma-joined) and togglable. Score off the WORST (highest-points)
      # stage in the set — eye-level when present, else the worst across per-image values.
      eye_stage = @state.value("stage")
      stage = worst_stage(eye_stage ? [eye_stage] : @state.image_values("stage"))
      return stage if stage.nil?
      return stage unless %w[4 5].include?(stage)

      # Legacy rows stored stage and its A/B/C degree separately; recombine into "4A", "5C", …
      legacy_suffix = @state.value("degrees_ab") || @state.value("degrees")
      return stage if legacy_suffix.nil?

      "#{stage}#{legacy_suffix.upcase}"
    end

    def plus_value
      @state.value("plus") || worst_image_value("PLUS", "plus")
    end

    def arop_value
      # Eye-level first, then "present on any image".
      return "AROP" if @state.present?("arop")

      @state.image_present?("arop") ? "AROP" : nil
    end

    # Worst (highest-points) stage among a list of possibly comma-joined stage values.
    def worst_stage(values)
      @state.expand(values).max_by { |v| @rules.points_for("STAGE", v).to_i }
    end

    # When the eye-level value of a component is blank, use the per-image value that yields the
    # highest points for that category (correct even where severity is inverted, e.g. Zone I).
    # Returns nil when there are no genuine per-image values.
    def worst_image_value(category, code)
      @state.image_values(code).max_by { |value| @rules.points_for(category, value).to_i }
    end

    def apply_cap(total)
      cap = @rules.cap
      cap.nil? ? total : [total, cap].min
    end
  end
end

# frozen_string_literal: true

require "test_helper"

# Conformance suite for the shared score. Every consuming project relies on these numbers, so a
# change here is a change to clinical output: add a new rule set version rather than editing one.
class ScorerTest < Minitest::Test
  def test_scores_zone_stage_and_plus
    result = score(values: { "zone" => "I", "stage" => "3", "plus" => "PRE" })

    assert_equal 60, result[:raw_total]
    assert_equal 60, result[:final_total]
    assert_equal "telerop_ss_v1", result[:rules_version]
  end

  def test_supports_stage_suffix_values
    result = score(values: { "zone" => "PZII", "stage" => "4B", "plus" => "NOPLUS" })
    labels = result[:components].map { |c| c.values_at(:category, :value, :points) }

    assert_includes labels, ["ZONE", "PZII", 20]
    assert_includes labels, ["STAGE", "4B", 89]
    assert_includes labels, ["PLUS", "NOPLUS", 0]
    assert_equal 109, result[:raw_total]
    assert_equal 100, result[:final_total], "cap applies"
  end

  def test_arop_scores_outright_ignoring_zone_stage_and_plus
    result = score(values: { "zone" => "I", "stage" => "5C", "plus" => "PLUS" }, present_codes: ["arop"])

    assert_equal 85, result[:raw_total]
    assert_equal 85, result[:final_total]
    assert_equal [["AROP", "AROP", 85]], result[:components].map { |c| c.values_at(:category, :value, :points) }
  end

  def test_arop_scores_even_when_nothing_else_is_graded
    assert_equal 85, score(present_codes: ["arop"])[:final_total]
  end

  def test_arop_present_on_any_image_is_terminal
    result = score(values: { "zone" => "II", "stage" => "1" }, image_present: ["arop"])

    assert_equal 85, result[:final_total]
  end

  def test_regression_state_overrides_numeric_stage
    result = score(values: { "zone" => "II", "stage" => "3", "plus" => "PRE" },
                   present_codes: ["regression_after_laser"])

    assert_equal "REGRESS-LASER", stage_component(result)[:value]
    assert_equal 30, result[:final_total]
  end

  def test_supports_legacy_split_stage_values
    result = score(values: { "zone" => "II", "stage" => "4", "degrees_ab" => "A", "plus" => "NOPLUS" })

    assert_equal "4A", stage_component(result)[:value]
    assert_equal 86, stage_component(result)[:points]
  end

  def test_multi_select_stage_scores_the_worst_member
    result = score(values: { "zone" => "II", "stage" => "1,3,2" })

    assert_equal "3", stage_component(result)[:value]
    assert_equal 25, stage_component(result)[:points]
  end

  def test_falls_back_to_the_worst_image_value_when_eye_level_is_blank
    result = score(image_values: { "zone" => ["II", "I"], "stage" => ["2", "3"], "plus" => ["PRE"] })
    by_category = result[:components].to_h { |c| [c[:category], c[:value]] }

    assert_equal "I", by_category["ZONE"], "Zone I is the worst zone despite the lower numeral"
    assert_equal "3", by_category["STAGE"]
    assert_equal "PRE", by_category["PLUS"]
  end

  def test_eye_level_value_wins_over_image_values
    result = score(values: { "zone" => "II" }, image_values: { "zone" => ["I"] })

    assert_equal "II", result[:components].find { |c| c[:category] == "ZONE" }[:value]
  end

  def test_unrecognized_values_are_left_out_of_the_breakdown
    result = score(values: { "zone" => "IV", "stage" => "2" })

    assert_equal ["STAGE"], result[:components].map { |c| c[:category] }
    assert_equal 10, result[:final_total]
  end

  def test_ungraded_eye_scores_zero_with_no_components
    result = score

    assert_equal 0, result[:final_total]
    assert_empty result[:components]
  end

  def test_accepts_a_plain_hash
    result = TeleropSs.score({ "zone" => "I", "stage" => "3", "plus" => "PRE" })

    assert_equal 60, result[:final_total]
  end

  def test_hash_booleans_are_cast
    assert_equal 85, TeleropSs.total({ "arop" => "true" })
    assert_equal 85, TeleropSs.total({ arop: true })
    assert_equal 0, TeleropSs.total({ "arop" => "false" })
  end

  def test_values_are_matched_case_insensitively
    assert_equal 30, TeleropSs.total({ "zone" => "i" })
  end

  private

  def score(**attrs)
    TeleropSs.score(FakeState.new(**attrs))
  end

  def stage_component(result)
    result[:components].find { |c| c[:category] == "STAGE" }
  end
end

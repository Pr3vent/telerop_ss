# frozen_string_literal: true

require "test_helper"

class RulesTest < Minitest::Test
  def test_ships_the_default_rule_set
    assert_includes TeleropSs::Rules.available_versions, "telerop_ss_v1"
    assert_equal "telerop_ss_v1", TeleropSs.rules.version
    assert_equal 100, TeleropSs.rules.cap
  end

  def test_points_lookup_is_case_insensitive_and_nil_for_unknown_values
    rules = TeleropSs.rules

    assert_equal 89, rules.points_for("stage", "4b")
    assert_nil rules.points_for("STAGE", "9Z")
    assert_nil rules.points_for("NOPE", "1")
  end

  def test_unknown_rule_set_raises
    assert_raises(TeleropSs::Rules::UnknownRuleSet) { TeleropSs.rules("telerop_ss_v99") }
  end

  def test_rule_sets_are_frozen
    assert_predicate TeleropSs.rules, :frozen?
  end
end

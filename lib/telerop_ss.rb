# frozen_string_literal: true

require "telerop_ss/version"
require "telerop_ss/rules"
require "telerop_ss/state"
require "telerop_ss/scorer"

# TeleROP severity scoring, shared across the projects that grade ROP exams.
#
#   TeleropSs.score(eye)                          # => { final_total: 60, ... }
#   TeleropSs.score(eye, rules: "telerop_ss_v1")  # pin an explicit rule set
#
# See TeleropSs::State for the interface the scored object has to provide (a plain Hash of
# code => value also works), and TeleropSs::Rules for the versioned point tables.
module TeleropSs
  def self.score(annotation_state, rules: Rules::DEFAULT_VERSION)
    Scorer.call(annotation_state, rules: rules)
  end

  # Convenience for the common case: just the capped number.
  def self.total(annotation_state, rules: Rules::DEFAULT_VERSION)
    score(annotation_state, rules: rules)[:final_total]
  end

  def self.rules(version = Rules::DEFAULT_VERSION)
    Rules.fetch(version)
  end
end

# telerop_ss

TeleROP severity score calculation, shared across the projects that grade ROP exams.

Plain Ruby, no runtime dependencies (not even Rails). One score, one point table, one set of
tests — so two projects grading the same eye cannot disagree.

## Install

Private gem; it is never pushed to rubygems.org.

```ruby
# Gemfile
gem "telerop_ss", git: "git@github.com:pr3vent/telerop_ss.git", tag: "v1.0.0"

# or, while developing the two side by side:
gem "telerop_ss", path: "../telerop_ss"
```

Pin a tag rather than tracking a branch: a moving score is a moving clinical result.

## Use

```ruby
TeleropSs.score(eye)
# => { raw_total: 60,
#      final_total: 60,
#      components: [{ category: "ZONE",  value: "I",   points: 30 },
#                   { category: "STAGE", value: "3",   points: 25 },
#                   { category: "PLUS",  value: "PRE", points: 5 }],
#      modifiers: [],
#      rules_version: "telerop_ss_v1" }

TeleropSs.total(eye)                          # => 60, just the capped number
TeleropSs.score(eye, rules: "telerop_ss_v1")  # pin an explicit rule set
```

Persist `rules_version` alongside any score you store. It is the only way to tell later whether
a number came from the table you are looking at now.

## What the scored object has to provide

Anything answering these reads works — normally the host app's eye record. The first two are
required; the image-level pair is optional and only used as a fallback.

```ruby
annotation_value(code)        # => String or nil, the graded eye-level value for a code
annotation_present?(code)     # => true/false, for presence-only booleans such as "arop"

image_level_values_for(code)  # => Array<String>, genuine per-image values (no eye-level fallback)
image_level_present?(code)    # => true/false, boolean present on any image
```

A plain Hash of `code => value` also works, which is what makes the gem usable from scripts and
fixtures:

```ruby
TeleropSs.total({ "zone" => "I", "stage" => "3", "plus" => "PRE" })  # => 60
```

Codes read: `zone`, `stage`, `plus`, `arop`, `regression_after_laser`,
`regression_par_after_anti_vegf`, `regression_spontaneous`, and the legacy `degrees_ab` /
`degrees`.

## Scoring rules

- **AROP is terminal.** An eye graded AROP scores its points outright; zone, stage and plus are
  not evaluated at all. AROP on any single image is enough.
- **Regression overrides stage.** Laser, anti-VEGF and spontaneous regression each replace the
  numeric stage.
- **Stage is multi-select** (comma-joined) and scores off the *worst* member, not the last one.
- **Blank eye-level values fall back to the worst image-level value** for that component — worst
  by points, so Zone I beats Zone II despite the lower numeral.
- **Legacy split stage** (`stage: "4"` + `degrees_ab: "A"`) recombines into `4A`.
- **Unrecognized values score nothing** and stay out of the breakdown, rather than counting zero.
- **The total is capped** at the rule set's cap (100 in v1).

## Rule sets

Point tables are versioned YAML files in [lib/telerop_ss/rules/](lib/telerop_ss/rules/). The
scoring *policy* is code; the *numbers* are data.

To change the numbers, **add a new version — never edit a shipped one**. Old files stay so that a
score persisted under `telerop_ss_v1` can still be reproduced after `telerop_ss_v2` lands:

```bash
cp lib/telerop_ss/rules/telerop_ss_v1.yml lib/telerop_ss/rules/telerop_ss_v2.yml
# edit version: telerop_ss_v2 and the points, then bump the gem's minor version
```

Consumers move over deliberately, one project at a time, by passing `rules:`.

## Development

```bash
rake test
```

The suite in [test/scorer_test.rb](test/scorer_test.rb) is the contract every consuming project
depends on. A change to an expected number there is a change to clinical output.

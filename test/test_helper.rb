# frozen_string_literal: true

require "minitest/autorun"
require "telerop_ss"

# Stand-in for the host app's eye record: the full annotation-state interface, nothing else.
FakeState = Struct.new(:values, :present_codes, :image_values, :image_present, keyword_init: true) do
  def annotation_value(code)
    (values || {}).fetch(code.to_s, nil)
  end

  def annotation_present?(code)
    Array(present_codes).include?(code.to_s)
  end

  def image_level_values_for(code)
    (image_values || {}).fetch(code.to_s, [])
  end

  def image_level_present?(code)
    Array(image_present).include?(code.to_s)
  end
end

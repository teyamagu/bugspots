# frozen_string_literal: true

module Bugspots
  Fix = Struct.new(:message, :date, :files)
  Spot = Struct.new(:file, :score)
  Complexity = Struct.new(:file, :score, :function_count)
  CombinedScore = Struct.new(:file, :combined_score, :hotspot_score, :cyclomatic_score,
                             :function_count)
end

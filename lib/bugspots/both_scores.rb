# frozen_string_literal: true

module Bugspots
  def self.combine_scores(hotspots, complexities)
    results = merge_score_sources(hotspots, complexities).map do |file, scores|
      build_combined_score(file, scores)
    end

    results.sort_by do |result|
      [-result.combined_score.to_f, -result.cyclomatic_score,
       -result.hotspot_score.to_f, result.file]
    end
  end

  # rubocop:disable Metrics/AbcSize
  def self.merge_score_sources(hotspots, complexities)
    merged_scores = Hash.new { |hash, file| hash[file] = default_combined_scores }

    hotspots.each do |spot|
      merged_scores[spot.file][:hotspot_score] = spot.score
    end

    complexities.each do |complexity|
      merged_scores[complexity.file][:cyclomatic_score] = complexity.score
      merged_scores[complexity.file][:function_count] = complexity.function_count
    end

    merged_scores
  end
  # rubocop:enable Metrics/AbcSize

  def self.build_combined_score(file, scores)
    CombinedScore.new(
      file,
      format('%.4f', scores[:hotspot_score].to_f * scores[:cyclomatic_score]),
      scores[:hotspot_score],
      scores[:cyclomatic_score],
      scores[:function_count]
    )
  end

  def self.default_combined_scores
    {
      hotspot_score: '0.0000',
      cyclomatic_score: 0,
      function_count: 0
    }
  end
end

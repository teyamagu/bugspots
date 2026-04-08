# frozen_string_literal: true

require 'minitest/autorun'

require 'bugspots'

class BothScoresTest < Minitest::Test
  def test_merge_combines_hotspot_and_cyclomatic_scores_and_sorts_by_product
    hotspot_results = [
      Bugspots::Spot.new('ruby_only.rb', '0.5000'),
      Bugspots::Spot.new('main.go', '0.3000')
    ]
    complexity_results = [
      Bugspots::Complexity.new('main.go', 7, 2),
      Bugspots::Complexity.new('only_complexity.ts', 4, 1)
    ]

    results = Bugspots.combine_scores(hotspot_results, complexity_results)

    assert_equal(
      [
        ['main.go', '2.1000', '0.3000', 7, 2],
        ['only_complexity.ts', '0.0000', '0.0000', 4, 1],
        ['ruby_only.rb', '0.0000', '0.5000', 0, 0]
      ],
      results.map do |result|
        [result.file, result.combined_score, result.hotspot_score, result.cyclomatic_score,
         result.function_count]
      end
    )
  end
end

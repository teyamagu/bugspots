# frozen_string_literal: true

module Bugspots
  module HotspotScores
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def self.calculate(fixes, current_time: Time.now)
      return [] if fixes.empty?

      hotspots = Hash.new(0)
      oldest_fix_date = fixes.min_by(&:date).date

      fixes.each do |fix|
        fix.files.each do |file|
          hotspots[file] += score_for_fix(fix.date, oldest_fix_date, current_time)
        end
      end

      hotspots
        .sort_by { |_file, score| score }
        .reverse
        .map { |file, score| Spot.new(file, format('%.4f', score)) }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def self.score_for_fix(fix_date, oldest_fix_date, current_time)
      # The timestamp used in the equation is normalized from 0 to 1, where
      # 0 is the earliest point in the code base, and 1 is now (where now is
      # when the algorithm was run). Note that the score changes over time
      # with this algorithm due to the moving normalization; it's not meant
      # to provide some objective score, only provide a means of comparison
      # between one file and another at any one point in time
      t = 1 - ((current_time - fix_date).to_f / (current_time - oldest_fix_date))
      1 / (1 + Math.exp((-12 * t) + 12))
    end
  end

  def self.hotspot_scores(fixes, current_time: Time.now)
    HotspotScores.calculate(fixes, current_time: current_time)
  end
end

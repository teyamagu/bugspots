# frozen_string_literal: true

require 'rugged'

module Bugspots
  # rubocop:disable Metrics/ParameterLists
  def self.scan(repo, branch = 'main', depth = nil, regex = nil, exclude_path_regex = nil)
    regex ||= /\b(fix(es|ed)?|close(s|d)?)\b/i

    raise ArgumentError, 'depth must be greater than or equal to 0' if depth&.negative?

    repo = Rugged::Repository.new(repo)
    ensure_branch_exists!(repo, branch)

    fixes = collect_fixes(repo, branch, depth, regex, exclude_path_regex)
    spots = hotspot_scores(fixes)
    [fixes, spots]
  end
  # rubocop:enable Metrics/ParameterLists

  def self.ensure_branch_exists!(repo, branch)
    return if repo.branches.each_name(:local).any? { |name| name == branch }

    raise ArgumentError, "no such branch in the repo: #{branch}"
  end

  def self.collect_fixes(repo, branch, depth, regex, exclude_path_regex)
    walker = Rugged::Walker.new(repo)
    walker.sorting(Rugged::SORT_TOPO)
    walker.push(repo.branches[branch].target)
    walker = walker.take(depth) if depth

    fixes = []
    walker.each do |commit|
      next unless commit.message.scrub =~ regex

      fixes << Fix.new(
        commit.message.scrub.split("\n").first,
        commit.time,
        collect_fix_files(commit, exclude_path_regex)
      )
    end

    fixes
  end

  def self.collect_fix_files(commit, exclude_path_regex)
    files = commit.diff(commit.parents.first).deltas.map { |delta| delta.old_file[:path] }
    return files unless exclude_path_regex

    files.reject { |file| file.match?(exclude_path_regex) }
  end
end

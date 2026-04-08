# frozen_string_literal: true

require 'minitest/autorun'

require 'bugspots'
require_relative 'support/repo_helpers'

class CyclomaticComplexityTest < Minitest::Test
  include RepoHelpers

  FakeMetric = Struct.new(:file, :score, :function_count)

  def test_scan_uses_branch_snapshot_and_excludes_paths
    captured_files = nil
    captured_contents = nil
    runner = lambda do |snapshot_root:, files:, languages:|
      captured_files = files
      captured_contents = files.to_h do |relative_path|
        [relative_path, File.read(File.join(snapshot_root, relative_path))]
      end

      [
        FakeMetric.new('ui/feature.ts', 3, 1),
        FakeMetric.new('main.go', 5, 2)
      ]
    end

    with_rugged_repo('bugspots-cyclomatic') do |repo_dir, repo|
      write_file(repo_dir, 'main.go', "package main\n")
      write_file(repo_dir, 'generated/skip.ts', 'export const skip = true;' + "\n")
      write_file(repo_dir, 'ignore.rb', "puts 'ignore'\n")
      commit_all(repo, 'initial commit')

      repo.create_branch('feature', repo.head.target_id)
      repo.checkout('refs/heads/feature')

      write_file(repo_dir, 'ui/feature.ts', 'export function feature() { return 1; }' + "\n")
      write_file(repo_dir, 'main.go', "package changed\n")
      commit_all(repo, 'feat: add feature')

      write_file(repo_dir, 'main.go', "package working_tree_only\n")

      results = Bugspots.cyclomatic_complexity(
        repo_dir,
        'feature',
        /^generated\//,
        runner: runner
      )

      assert_equal ['main.go', 'ui/feature.ts'], captured_files.sort
      assert_equal "package changed\n", captured_contents['main.go']
      refute_includes captured_files, 'generated/skip.ts'
      refute_includes captured_files, 'ignore.rb'
      assert_equal(
        [
          ['main.go', 5, 2],
          ['ui/feature.ts', 3, 1]
        ],
        results.map { |metric| [metric.file, metric.score, metric.function_count] }
      )
    end
  end

  def test_scan_returns_empty_when_no_supported_files_exist
    runner_called = false
    runner = lambda do |**_kwargs|
      runner_called = true
      []
    end

    with_rugged_repo('bugspots-cyclomatic') do |repo_dir, repo|
      write_file(repo_dir, 'README.md', "# docs\n")
      commit_all(repo, 'docs: add readme')

      results = Bugspots.cyclomatic_complexity(repo_dir, current_branch(repo), nil, runner: runner)

      assert_empty results
      refute runner_called
    end
  end

  def test_scan_skips_non_blob_tree_entries_without_lookup
    entries = [
      { name: 'vendor-submodule', type: :commit, oid: :missing_oid },
      { name: 'main.go', type: :blob, oid: :blob_oid }
    ]
    tree = Struct.new(:entries) do
      def each(&block)
        entries.each(&block)
      end
    end.new(entries)
    blob = Struct.new(:content).new("package main\n")
    repo = Object.new

    repo.define_singleton_method(:lookup) do |oid|
      raise 'should not lookup gitlink entry' if oid == :missing_oid

      blob
    end

    collected = []
    Bugspots::CyclomaticComplexity.collect_tree_entries(repo, tree, nil, collected, nil)

    assert_equal [{ path: 'main.go', content: "package main\n" }], collected
  end

  def test_scan_batches_large_file_lists_for_runner
    calls = []
    runner = lambda do |snapshot_root:, files:, languages:|
      calls << [snapshot_root, files, languages]
      files.map { |file| FakeMetric.new(file, 1, 1) }
    end

    with_rugged_repo('bugspots-cyclomatic') do |repo_dir, repo|
      3.times do |index|
        write_file(repo_dir, "pkg/file_#{index}.go", "package main\n")
      end
      commit_all(repo, 'feat: add go files')

      results = Bugspots.cyclomatic_complexity(
        repo_dir,
        current_branch(repo),
        nil,
        runner: runner,
        batch_size: 2
      )

      assert_equal 2, calls.size
      assert_equal ['pkg/file_0.go', 'pkg/file_1.go'], calls[0][1]
      assert_equal ['pkg/file_2.go'], calls[1][1]
      assert_equal 3, results.size
    end
  end
end

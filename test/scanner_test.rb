# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'

require 'bugspots'
require_relative 'support/repo_helpers'

class BugspotsScannerTest < Minitest::Test
  include RepoHelpers

  def test_scan_excludes_matching_paths
    with_scanner_repo do |repo_dir, repo|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      write_file(repo_dir, 'generated/schema.rb', "# schema v1\n")
      commit_all(repo, 'initial commit')

      write_file(repo_dir, 'app.rb', "puts 'hello world'\n")
      write_file(repo_dir, 'generated/schema.rb', "# schema v2\n")
      commit_all(repo, 'fix: adjust greeting')

      fixes, spots = Bugspots.scan(repo_dir, repo.head.name.delete_prefix('refs/heads/'), nil, nil, /^generated\//)

      assert_equal 1, fixes.size
      assert_equal ['app.rb'], fixes.first.files
      assert_equal ['app.rb'], spots.map(&:file)
    end
  end

  def test_scan_returns_empty_results_when_no_bugfix_commits_match
    with_scanner_repo do |repo_dir, repo|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      commit_all(repo, 'chore: initial commit')

      fixes, spots = Bugspots.scan(repo_dir, current_branch(repo))

      assert_empty fixes
      assert_empty spots
    end
  end

  def test_scan_returns_empty_results_when_depth_is_zero
    with_scanner_repo do |repo_dir, repo|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      commit_all(repo, 'fix: initial commit')

      fixes, spots = Bugspots.scan(repo_dir, current_branch(repo), 0)

      assert_empty fixes
      assert_empty spots
    end
  end

  def test_scan_rejects_negative_depth
    with_scanner_repo do |repo_dir, repo|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      commit_all(repo, 'fix: initial commit')

      error = assert_raises(ArgumentError) do
        Bugspots.scan(repo_dir, current_branch(repo), -1)
      end

      assert_equal 'depth must be greater than or equal to 0', error.message
    end
  end

  def test_scan_uses_the_oldest_fix_date_even_if_fixes_are_not_in_chronological_order
    reference_time = Time.now
    older_fix = fake_commit('fix: older', reference_time - 3600, 'older.rb')
    newer_fix = fake_commit('fix: newer', reference_time - 1800, 'newer.rb')
    walker = FakeWalker.new([older_fix, newer_fix])
    repo = FakeRepo.new('main', :head_target)

    with_stubbed_singleton_method(Rugged::Repository, :new, repo) do
      with_stubbed_singleton_method(Rugged::Walker, :new, walker) do
        fixes, spots = Bugspots.scan('/fake/repo')

        assert_equal ['fix: older', 'fix: newer'], fixes.map(&:message)
        assert_equal ['newer.rb', 'older.rb'], spots.map(&:file)
        refute_equal '0.0000', spots.first.score
        assert_equal '0.0000', spots.last.score
      end
    end
  end

  private

  module ScanDoubles
    FakeBranch = Struct.new(:target)
    FakeDelta = Struct.new(:old_file)
    FakeDiff = Struct.new(:deltas)

    class FakeBranches
      def initialize(branch_name, target)
        @branch_name = branch_name
        @target = target
      end

      def each_name(_type)
        [@branch_name]
      end

      def [](branch_name)
        return FakeBranch.new(@target) if branch_name == @branch_name

        nil
      end
    end

    class FakeRepo
      attr_reader :branches

      def initialize(branch_name, target)
        @branches = FakeBranches.new(branch_name, target)
      end
    end

    class FakeWalker
      def initialize(commits)
        @commits = commits
      end

      def sorting(_mode); end

      def push(_target); end

      def take(depth)
        @commits.take(depth)
      end

      def each(&block)
        @commits.each(&block)
      end
    end

    def fake_commit(message, time, path)
      diff = FakeDiff.new([FakeDelta.new({ path: path })])
      Struct.new(:message, :time, :parents, :diff_result) do
        def diff(_parent)
          diff_result
        end
      end.new(message, time, [:parent], diff)
    end
  end

  include ScanDoubles

  def with_scanner_repo(&block)
    with_rugged_repo('bugspots-scanner', &block)
  end

  def with_stubbed_singleton_method(klass, method_name, return_value)
    singleton = klass.singleton_class
    original_method = klass.method(method_name)

    singleton.send(:define_method, method_name) { |*_args, **_kwargs, &_block| return_value }
    yield
  ensure
    singleton.send(:define_method, method_name) do |*args, **kwargs, &block|
      original_method.call(*args, **kwargs, &block)
    end
  end
end

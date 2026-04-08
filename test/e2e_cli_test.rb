# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require_relative 'support/repo_helpers'

class E2EBugspotsCliTest < Minitest::Test
  include RepoHelpers

  ANSI_ESCAPE = /\e\[[0-9;]*m/

  def test_bugspots_cli_reports_fix_and_hotspot
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'initial commit')

      write_file(repo_dir, 'app.rb', "puts 'hello world'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: adjust greeting')

      stdout, stderr, status = run_bugspots(repo_dir)
      assert status.success?, "CLI failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"

      output = strip_ansi(stdout)
      assert_includes output, "Scanning #{repo_dir} repo"
      assert_includes output, 'Found 1 bugfix commits, with 1 hotspots:'
      assert_match(/-\sfix: adjust greeting/, output)
      assert_match(/-\sapp\.rb/, output)
    end
  end

  def test_bugspots_cli_excludes_paths_from_hotspots
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      write_file(repo_dir, 'generated/schema.rb', "# schema v1\n")
      git(repo_dir, 'add', 'app.rb', 'generated/schema.rb')
      git(repo_dir, 'commit', '-m', 'initial commit')

      write_file(repo_dir, 'app.rb', "puts 'hello world'\n")
      write_file(repo_dir, 'generated/schema.rb', "# schema v2\n")
      git(repo_dir, 'add', 'app.rb', 'generated/schema.rb')
      git(repo_dir, 'commit', '-m', 'fix: adjust greeting')

      stdout, stderr, status = run_bugspots(repo_dir, '--exclude-path', '/^generated\\//')
      assert status.success?, "CLI failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"

      output = strip_ansi(stdout)
      assert_includes output, 'Found 1 bugfix commits, with 1 hotspots:'
      assert_match(/-\sapp\.rb/, output)
      refute_match(/-\sgenerated\/schema\.rb/, output)
    end
  end

  def test_bugspots_cli_reports_zero_results_when_no_bugfix_commits_match
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'chore: initial commit')

      stdout, stderr, status = run_bugspots(repo_dir)

      assert status.success?, "CLI failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"

      output = strip_ansi(stdout)
      assert_includes output, 'Found 0 bugfix commits, with 0 hotspots:'
      refute_match(/NoMethodError/, stderr)
    end
  end

  def test_bugspots_cli_reports_missing_branch_as_user_facing_error
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: initial commit')

      stdout, stderr, status = run_bugspots(repo_dir, '-b', 'does-not-exist')

      refute status.success?, 'CLI unexpectedly succeeded'
      assert_includes strip_ansi(stdout), "Scanning #{repo_dir} repo"
      assert_equal "no such branch in the repo: does-not-exist\n", strip_ansi(stderr)
    end
  end

  def test_bugspots_cli_reports_zero_results_when_depth_is_zero
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: initial commit')

      stdout, stderr, status = run_bugspots(repo_dir, '-d', '0')

      assert status.success?, "CLI failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
      assert_includes strip_ansi(stdout), 'Found 0 bugfix commits, with 0 hotspots:'
    end
  end

  def test_bugspots_cli_rejects_negative_depth
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: initial commit')

      stdout, stderr, status = run_bugspots(repo_dir, '--depth=-1')

      refute status.success?, 'CLI unexpectedly succeeded'
      assert_includes strip_ansi(stdout), "Scanning #{repo_dir} repo"
      assert_equal "depth must be greater than or equal to 0\n", strip_ansi(stderr)
    end
  end

  private

  def with_cli_repo(&block)
    with_tmp_repo('bugspots-e2e') do |repo_dir|
      init_cli_repo(repo_dir)
      block.call(repo_dir)
    end
  end

  def run_bugspots(repo_dir, *args)
    Open3.capture3(
      { 'RUBYOPT' => nil },
      Gem.ruby,
      File.expand_path('../bin/bugspots', __dir__),
      repo_dir,
      *args
    )
  end

  def strip_ansi(text)
    text.gsub(ANSI_ESCAPE, '')
  end
end

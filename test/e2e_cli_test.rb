# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'support/cli_test_helpers'
require_relative 'support/repo_helpers'

class E2EBugspotsCliTest < Minitest::Test
  include CliTestHelpers
  include RepoHelpers

  def test_bugspots_cli_reports_fix_and_hotspot
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'initial commit')

      write_file(repo_dir, 'app.rb', "puts 'hello world'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: adjust greeting')

      stdout, stderr, status = run_bugspots(repo_dir)
      assert_cli_success(status, stdout, stderr)

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
      assert_cli_success(status, stdout, stderr)

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
      assert_cli_success(status, stdout, stderr)

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

      assert_cli_option_error(repo_dir, ['-b', 'does-not-exist'], 'no such branch in the repo: does-not-exist')
    end
  end

  def test_bugspots_cli_reports_zero_results_when_depth_is_zero
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: initial commit')

      stdout, stderr, status = run_bugspots(repo_dir, '-d', '0')

      assert_cli_success(status, stdout, stderr)
      assert_includes strip_ansi(stdout), 'Found 0 bugfix commits, with 0 hotspots:'
    end
  end

  def test_bugspots_cli_rejects_negative_depth
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'app.rb', "puts 'hello'\n")
      git(repo_dir, 'add', 'app.rb')
      git(repo_dir, 'commit', '-m', 'fix: initial commit')

      assert_cli_option_error(repo_dir, ['--depth=-1'], 'depth must be greater than or equal to 0')
    end
  end

  def test_bugspots_cli_reports_cyclomatic_complexity_scores
    with_cli_repo do |repo_dir|
      write_file(
        repo_dir,
        'main.go',
        <<~GO
          package main

          func first() {}
          func second() {}
        GO
      )
      write_file(
        repo_dir,
        'web/app.ts',
        <<~TS
          export function alpha() { return 1; }
        TS
      )
      git(repo_dir, 'add', 'main.go', 'web/app.ts')
      git(repo_dir, 'commit', '-m', 'feat: add source files')

      stdout, stderr, status = run_bugspots(
        repo_dir,
        '-c',
        env: fake_lizard_env(repo_dir)
      )

      assert_cli_success(status, stdout, stderr)

      output = strip_ansi(stdout)
      assert_includes output, 'Found 2 files with cyclomatic complexity:'
      assert_match(/7 \(2 functions\) - main\.go/, output)
      assert_match(/4 \(1 functions\) - web\/app\.ts/, output)
      assert_empty stderr
    end
  end

  def test_bugspots_cli_cyclomatic_mode_honors_branch_and_exclude_path
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'main.go', "package main\nfunc base() {}\n")
      write_file(repo_dir, 'generated/skip.ts', "export function skip() { return 1; }\n")
      git(repo_dir, 'add', 'main.go', 'generated/skip.ts')
      git(repo_dir, 'commit', '-m', 'feat: base')

      git(repo_dir, 'checkout', '-b', 'feature')
      write_file(repo_dir, 'feature.ts', "export function feature() { return 1; }\n")
      git(repo_dir, 'add', 'feature.ts')
      git(repo_dir, 'commit', '-m', 'feat: branch file')
      git(repo_dir, 'checkout', 'main')

      stdout, stderr, status = run_bugspots(
        repo_dir,
        '-c',
        '-b',
        'feature',
        '--exclude-path',
        '/^generated\\//',
        env: fake_lizard_env(repo_dir)
      )

      assert_cli_success(status, stdout, stderr)

      output = strip_ansi(stdout)
      assert_match(/2 \(1 functions\) - feature\.ts/, output)
      assert_match(/7 \(2 functions\) - main\.go/, output)
      refute_match(/generated\/skip\.ts/, output)
    end
  end

  def test_bugspots_cli_cyclomatic_mode_rejects_incompatible_options
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'main.go', "package main\nfunc base() {}\n")
      git(repo_dir, 'add', 'main.go')
      git(repo_dir, 'commit', '-m', 'feat: base')

      assert_cyclomatic_option_error(repo_dir, ['-d', '1'], '-d')
      assert_cyclomatic_option_error(repo_dir, ['-w', 'fix'], '-w')
      assert_cyclomatic_option_error(repo_dir, ['-r', '/fix/'], '-r')
      assert_cyclomatic_option_error(repo_dir, ['--display-timestamps'], '--display-timestamps')
    end
  end

  def test_bugspots_cli_cyclomatic_mode_handles_large_file_sets
    with_cli_repo do |repo_dir|
      205.times do |index|
        write_file(repo_dir, "pkg/file_#{index}.ts", "export function f#{index}() { return #{index}; }\n")
      end
      git(repo_dir, 'add', 'pkg')
      git(repo_dir, 'commit', '-m', 'feat: add many files')

      stdout, stderr, status = run_bugspots(
        repo_dir,
        '-c',
        env: fake_lizard_env(repo_dir)
      )

      assert_cli_success(status, stdout, stderr)

      output = strip_ansi(stdout)
      assert_includes output, 'Found 205 files with cyclomatic complexity:'
      assert_match(/1 \(1 functions\) - pkg\/file_0\.ts/, output)
      assert_match(/1 \(1 functions\) - pkg\/file_204\.ts/, output)
      refute_match(/Argument list too long/, stderr)
    end
  end

  def test_bugspots_cli_reports_combined_scores
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'main.go', "package main\nfunc base() {}\n")
      write_file(repo_dir, 'ruby_only.rb', "puts 'hello'\n")
      write_file(repo_dir, 'only_complexity.ts', "export function alpha() { return 1; }\n")
      git(repo_dir, 'add', 'main.go', 'ruby_only.rb', 'only_complexity.ts')
      git(repo_dir, 'commit', '-m', 'initial commit')

      write_file(repo_dir, 'main.go', "package main\nfunc changed() {}\n")
      write_file(repo_dir, 'ruby_only.rb', "puts 'fixed'\n")
      git(repo_dir, 'add', 'main.go', 'ruby_only.rb')
      git(repo_dir, 'commit', '-m', 'fix: update files')

      write_file(repo_dir, 'main.go', "package main\nfunc changedAgain() {}\n")
      write_file(repo_dir, 'ruby_only.rb', "puts 'fixed again'\n")
      git(repo_dir, 'add', 'main.go', 'ruby_only.rb')
      git(repo_dir, 'commit', '-m', 'fix: update files again')

      stdout, stderr, status = run_bugspots(
        repo_dir,
        '--both',
        env: fake_lizard_env(repo_dir)
      )

      assert_cli_success(status, stdout, stderr)

      output = strip_ansi(stdout)
      assert_includes output, 'Found 3 files with combined scores:'
      assert_match(/[0-9]+\.[0-9]{4} \(hotspot: [0-9]+\.[0-9]{4}, cyclomatic: 7, functions: 2\) - main\.go/, output)
      assert_match(/0\.0000 \(hotspot: 0\.0000, cyclomatic: 4, functions: 1\) - only_complexity\.ts/, output)
      assert_match(/0\.0000 \(hotspot: [0-9]+\.[0-9]{4}, cyclomatic: 0, functions: 0\) - ruby_only\.rb/, output)
    end
  end

  def test_bugspots_cli_both_mode_honors_branch_and_exclude_path
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'main.go', "package main\nfunc base() {}\n")
      write_file(repo_dir, 'generated/skip.ts', "export function skip() { return 1; }\n")
      git(repo_dir, 'add', 'main.go', 'generated/skip.ts')
      git(repo_dir, 'commit', '-m', 'initial commit')

      git(repo_dir, 'checkout', '-b', 'feature')
      write_file(repo_dir, 'feature.ts', "export function feature() { return 1; }\n")
      git(repo_dir, 'add', 'feature.ts')
      git(repo_dir, 'commit', '-m', 'fix: add feature')
      write_file(repo_dir, 'feature.ts', "export function feature() { return 2; }\n")
      git(repo_dir, 'add', 'feature.ts')
      git(repo_dir, 'commit', '-m', 'fix: update feature')
      git(repo_dir, 'checkout', 'main')

      stdout, stderr, status = run_bugspots(
        repo_dir,
        '--both',
        '-b',
        'feature',
        '--exclude-path',
        '/^generated\\//',
        env: fake_lizard_env(repo_dir)
      )

      assert_cli_success(status, stdout, stderr)

      output = strip_ansi(stdout)
      assert_match(/[0-9]+\.[0-9]{4} \(hotspot: [0-9]+\.[0-9]{4}, cyclomatic: 2, functions: 1\) - feature\.ts/, output)
      refute_match(/generated\/skip\.ts/, output)
    end
  end

  def test_bugspots_cli_both_mode_rejects_incompatible_options
    with_cli_repo do |repo_dir|
      write_file(repo_dir, 'main.go', "package main\nfunc base() {}\n")
      git(repo_dir, 'add', 'main.go')
      git(repo_dir, 'commit', '-m', 'feat: base')

      assert_both_option_error(repo_dir, ['-d', '1'], '-d')
      assert_both_option_error(repo_dir, ['-w', 'fix'], '-w')
      assert_both_option_error(repo_dir, ['-r', '/fix/'], '-r')
      assert_both_option_error(repo_dir, ['--display-timestamps'], '--display-timestamps')
      assert_both_option_error(repo_dir, ['-c'], '-c')
    end
  end

  private

  def assert_cyclomatic_option_error(repo_dir, args, flag)
    assert_cli_option_error(repo_dir, ['-c', *args], "option #{flag} is not available with -c")
  end

  def assert_both_option_error(repo_dir, args, flag)
    assert_cli_option_error(repo_dir, ['--both', *args], "option #{flag} is not available with --both")
  end
end

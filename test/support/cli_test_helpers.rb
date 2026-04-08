# frozen_string_literal: true

require 'fileutils'
require 'open3'

module CliTestHelpers
  ANSI_ESCAPE = /\e\[[0-9;]*m/

  private

  def with_cli_repo(&block)
    with_tmp_repo('bugspots-e2e') do |repo_dir|
      init_cli_repo(repo_dir)
      block.call(repo_dir)
    end
  end

  def run_bugspots(repo_dir, *args, env: {})
    Open3.capture3(
      { 'RUBYOPT' => nil }.merge(env),
      Gem.ruby,
      File.expand_path('../../bin/bugspots', __dir__),
      repo_dir,
      *args
    )
  end

  def strip_ansi(text)
    text.gsub(ANSI_ESCAPE, '')
  end

  def assert_cli_success(status, stdout, stderr)
    assert status.success?, "CLI failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
  end

  def assert_cli_option_error(repo_dir, args, expected_message)
    stdout, stderr, status = run_bugspots(repo_dir, *args)

    refute status.success?, 'CLI unexpectedly succeeded'
    assert_includes strip_ansi(stdout), "Scanning #{repo_dir} repo"
    assert_equal "#{expected_message}\n", strip_ansi(stderr)
  end

  def fake_lizard_env(repo_dir)
    module_dir = File.join(repo_dir, 'test-python')
    FileUtils.mkdir_p(module_dir)
    File.write(
      File.join(module_dir, 'lizard.py'),
      <<~PY
        import os

        class FunctionInfo:
            def __init__(self, ccn):
                self.cyclomatic_complexity = ccn

        class Analysis:
            def __init__(self, functions):
                self.function_list = functions

        def analyze_file(path):
            rel = os.path.relpath(path, os.getcwd()).replace('\\\\', '/')
            if rel == 'main.go':
                return Analysis([FunctionInfo(3), FunctionInfo(4)])
            if rel == 'web/app.ts':
                return Analysis([FunctionInfo(4)])
            if rel == 'feature.ts':
                return Analysis([FunctionInfo(2)])
            if rel == 'generated/skip.ts':
                return Analysis([FunctionInfo(9)])
            if rel == 'only_complexity.ts':
                return Analysis([FunctionInfo(4)])
            if rel.endswith('.go') or rel.endswith('.ts') or rel.endswith('.tsx'):
                return Analysis([FunctionInfo(1)])
            return Analysis([])
      PY
    )

    { 'PYTHONPATH' => module_dir }
  end
end

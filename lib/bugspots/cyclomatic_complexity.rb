# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'rugged'
require 'tmpdir'

module Bugspots
  # rubocop:disable Metrics/ModuleLength
  module CyclomaticComplexity
    LANGUAGE_DEFINITIONS = {
      go: {
        extensions: ['.go'],
        lizard_language: 'go'
      },
      typescript: {
        extensions: ['.ts', '.tsx'],
        lizard_language: 'typescript'
      }
    }.freeze

    LIZARD_SCRIPT = <<~PY
      import json
      import sys

      try:
          import lizard
      except ImportError:
          sys.stderr.write("BUGSPOTS_LIZARD_IMPORT_ERROR")
          sys.exit(2)

      results = []
      for path in sys.argv[1:]:
          analysis = lizard.analyze_file(path)
          results.append({
              "file": path,
              "score": sum(function.cyclomatic_complexity for function in analysis.function_list),
              "function_count": len(analysis.function_list),
          })

      print(json.dumps(results))
    PY

    DEFAULT_BATCH_SIZE = 200
    MISSING_LIZARD_MESSAGE = 'cyclomatic complexity mode requires Python package "lizard". '\
                             'Install it with: pip install lizard'

    # rubocop:disable Metrics/MethodLength
    def self.scan(repo_path, branch = 'main', exclude_path_regex = nil,
                  runner: method(:run_lizard), batch_size: DEFAULT_BATCH_SIZE)
      repo = Rugged::Repository.new(repo_path)
      Bugspots.ensure_branch_exists!(repo, branch)

      files = snapshot_supported_files(repo, branch, exclude_path_regex)
      return [] if files.empty?

      Dir.mktmpdir('bugspots-cyclomatic') do |dir|
        write_snapshot(dir, files)
        results = files
                  .map { |file| file[:path] }
                  .each_slice(batch_size)
                  .flat_map do |batch|
                    runner.call(
                      snapshot_root: dir,
                      files: batch,
                      _languages: supported_lizard_languages
                    )
                  end
        normalize_results(results)
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.snapshot_supported_files(repo, branch, exclude_path_regex)
      tree = repo.branches[branch].target.tree
      entries = []
      collect_tree_entries(repo, tree, nil, entries, exclude_path_regex)
      entries
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def self.collect_tree_entries(repo, tree, base_path, entries, exclude_path_regex)
      tree.each do |entry|
        relative_path = [base_path, entry[:name]].compact.join('/')
        next if exclude_path_regex && relative_path.match?(exclude_path_regex)

        if entry[:type] == :tree
          collect_tree_entries(repo, repo.lookup(entry[:oid]), relative_path, entries,
                               exclude_path_regex)
          next
        end

        next unless entry[:type] == :blob
        next unless supported_file?(relative_path)

        entries << { path: relative_path, content: repo.lookup(entry[:oid]).content }
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def self.supported_file?(path)
      LANGUAGE_DEFINITIONS.values.any? do |definition|
        definition[:extensions].any? { |extension| path.end_with?(extension) }
      end
    end

    def self.supported_lizard_languages
      LANGUAGE_DEFINITIONS.values.map { |definition| definition[:lizard_language] }.uniq
    end

    def self.write_snapshot(root, files)
      files.each do |file|
        path = File.join(root, file[:path])
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, file[:content])
      end
    end

    # rubocop:disable Metrics/MethodLength
    def self.run_lizard(snapshot_root:, files:, _languages:)
      stdout, stderr, status = Open3.capture3(
        lizard_env,
        lizard_python_command,
        '-c',
        LIZARD_SCRIPT,
        *files,
        chdir: snapshot_root
      )

      unless status.success?
        raise_missing_lizard_error if stderr.include?('BUGSPOTS_LIZARD_IMPORT_ERROR')

        raise ArgumentError, "failed to run lizard: #{stderr.strip}"
      end

      JSON.parse(stdout, symbolize_names: true).map do |result|
        Complexity.new(
          result[:file],
          result[:score],
          result[:function_count]
        )
      end
    end
    # rubocop:enable Metrics/MethodLength

    def self.lizard_python_command
      return ENV['BUGSPOTS_LIZARD_PYTHON'] if ENV['BUGSPOTS_LIZARD_PYTHON']

      local_python = File.expand_path('../../.venv/bin/python3', __dir__)
      return local_python if File.executable?(local_python)

      'python3'
    end

    def self.lizard_env
      env = {}
      env['PYTHONPATH'] = ENV['PYTHONPATH'] if ENV['PYTHONPATH']
      env
    end

    def self.raise_missing_lizard_error
      raise ArgumentError, MISSING_LIZARD_MESSAGE
    end

    def self.normalize_results(results)
      normalized = results.map do |result|
        relative_path = result.file.sub(%r{\A\./}, '')
        Complexity.new(relative_path, result.score.to_i, result.function_count.to_i)
      end

      normalized.sort_by { |result| [-result.score, -result.function_count, result.file] }
    end
  end
  # rubocop:enable Metrics/ModuleLength

  def self.cyclomatic_complexity(repo_path, branch = 'main', exclude_path_regex = nil,
                                 runner: CyclomaticComplexity.method(:run_lizard),
                                 batch_size: CyclomaticComplexity::DEFAULT_BATCH_SIZE)
    CyclomaticComplexity.scan(
      repo_path,
      branch,
      exclude_path_regex,
      runner: runner,
      batch_size: batch_size
    )
  end
end

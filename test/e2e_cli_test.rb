require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class E2EBugspotsCliTest < Minitest::Test
  ANSI_ESCAPE = /\e\[[0-9;]*m/

  def test_bugspots_cli_reports_fix_and_hotspot
    Dir.mktmpdir("bugspots-e2e") do |dir|
      repo_dir = File.join(dir, "sample-repo")
      FileUtils.mkdir_p(repo_dir)

      git(repo_dir, "init", "-b", "main")
      git(repo_dir, "config", "user.name", "Bugspots Test")
      git(repo_dir, "config", "user.email", "bugspots@example.com")

      app_file = File.join(repo_dir, "app.rb")
      File.write(app_file, "puts 'hello'\n")
      git(repo_dir, "add", "app.rb")
      git(repo_dir, "commit", "-m", "initial commit")

      File.write(app_file, "puts 'hello world'\n")
      git(repo_dir, "add", "app.rb")
      git(repo_dir, "commit", "-m", "fix: adjust greeting")

      stdout, stderr, status = Open3.capture3(
        {"RUBYOPT" => nil},
        Gem.ruby,
        File.expand_path("../bin/bugspots", __dir__),
        repo_dir
      )

      assert status.success?, "CLI failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"

      output = strip_ansi(stdout)
      assert_includes output, "Scanning #{repo_dir} repo"
      assert_includes output, "Found 1 bugfix commits, with 1 hotspots:"
      assert_match(/\-\sfix: adjust greeting/, output)
      assert_match(/-\sapp\.rb/, output)
    end
  end

  private

  def git(dir, *args)
    stdout, stderr, status = Open3.capture3("git", *args, chdir: dir)
    return if status.success?

    flunk "git #{args.join(' ')} failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
  end

  def strip_ansi(text)
    text.gsub(ANSI_ESCAPE, "")
  end
end

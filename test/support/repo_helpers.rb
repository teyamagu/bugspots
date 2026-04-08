# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'rugged'
require 'tmpdir'

module RepoHelpers
  private

  def with_tmp_repo(tmp_prefix)
    Dir.mktmpdir(tmp_prefix) do |dir|
      repo_dir = File.join(dir, 'sample-repo')
      FileUtils.mkdir_p(repo_dir)
      yield repo_dir
    end
  end

  def with_rugged_repo(tmp_prefix)
    with_tmp_repo(tmp_prefix) do |repo_dir|
      yield repo_dir, init_rugged_repo(repo_dir)
    end
  end

  def init_rugged_repo(repo_dir)
    repo = Rugged::Repository.init_at(repo_dir, false)
    repo.config['user.name'] = 'Bugspots Test'
    repo.config['user.email'] = 'bugspots@example.com'
    repo
  end

  def init_cli_repo(repo_dir)
    git(repo_dir, 'init', '-b', 'main')
    git(repo_dir, 'config', 'user.name', 'Bugspots Test')
    git(repo_dir, 'config', 'user.email', 'bugspots@example.com')
  end

  def write_file(repo_dir, relative_path, content)
    path = File.join(repo_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def commit_all(repo, message)
    index = repo.index
    index.add_all
    index.write

    Rugged::Commit.create(
      repo,
      tree: index.write_tree(repo),
      author: signature(repo),
      committer: signature(repo),
      message: message,
      parents: repo.empty? ? [] : [repo.head.target].compact,
      update_ref: 'HEAD'
    )
  end

  def current_branch(repo)
    repo.head.name.delete_prefix('refs/heads/')
  end

  def git(dir, *args)
    stdout, stderr, status = Open3.capture3('git', *args, chdir: dir)
    return if status.success?

    flunk "git #{args.join(' ')} failed.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
  end

  def signature(repo)
    {
      email: repo.config['user.email'],
      name: repo.config['user.name'],
      time: Time.now
    }
  end
end

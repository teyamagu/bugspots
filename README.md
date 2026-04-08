# Bugspots

[![CI](https://github.com/teyamagu/bugspots/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/teyamagu/bugspots/actions/workflows/ci.yml)

`bugspots` is a Ruby CLI for analyzing Git repositories with three reporting
modes:

- historical bug-fix hotspots
- file-level cyclomatic complexity for Go / TypeScript
- a combined score that multiplies hotspot and cyclomatic scores

The approach is based on Google Engineering's write-up:
[Bug Prediction at Google](http://google-engtools.blogspot.com/2011/12/bug-prediction-at-google.html)

> Well, we actually have a great, authoritative record of where code has been
> requiring fixes: our bug tracker and our source control commit log! The
> research indicates that predicting bugs from the source history works very
> well, so we decided to deploy it at Google.

Point `bugspots` at any Git repository and it will identify likely hotspots for you.

## Features

- Scan a local Git repository and identify bug-fix commits.
- Score files by historical bug-fix concentration.
- Measure file-level cyclomatic complexity for Go / TypeScript using `lizard`.
- Combine hotspot and cyclomatic scores into a single sortable view.
- Run as a standalone CLI or as a `git bugspots` subcommand.
- Default to the `main` branch while allowing explicit branch selection.

## Requirements

- Ruby `4.0.1`
- Git repository to analyze
- Native build tooling for `rugged`
- Python 3 + `lizard` when using cyclomatic complexity modes (`-c`, `--both`)
  - macOS: `pkg-config`, `cmake`, Xcode Command Line Tools
  - Ubuntu/Debian: `pkg-config`, `cmake`, build-essential

## Installation

### Install from RubyGems

```bash
gem install bugspots
```

### Install from source

```bash
git clone git@github.com:teyamagu/bugspots.git
cd bugspots
bundle install
python3 -m venv .venv
.venv/bin/pip install lizard
```

If `rugged` fails to build, install system packages first.

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y pkg-config cmake build-essential
```

macOS with Homebrew:

```bash
brew install pkg-config cmake
```

## Usage

### Basic usage

```bash
bugspots /path/to/repo
```

### Reporting modes

Default hotspot mode:

```bash
bugspots /path/to/repo
```

Cyclomatic complexity mode:

```bash
bugspots /path/to/repo -c
```

Combined mode:

```bash
bugspots /path/to/repo --both
```

### Run inside a target repository

```bash
cd /path/to/repo
git bugspots
```

### Common examples

```bash
bugspots /path/to/repo -b main -d 500
bugspots /path/to/repo --display-timestamps
bugspots /path/to/repo -w "fix,close"
bugspots /path/to/repo -r '/fix(es|ed)? #(\d+)/i'
bugspots /path/to/repo --exclude-path '/^generated\\//'
bugspots /path/to/repo -c --branch main --exclude-path '/^generated\\//'
bugspots /path/to/repo --both --branch main --exclude-path '/^generated\\//'
```

Options:

- `-c`, `--cyclomatic-complexity`: report file-level cyclomatic complexity for Go / TypeScript files. Output is `sum(CCN per function)` plus function count for each file.
- `--both`: report file-level combined scores using `hotspot_score * cyclomatic_score`. Output also includes the underlying hotspot score, cyclomatic score, and function count.
- `-b`, `--branch [name]`: branch to scan. Default is `main`.
- `-d`, `--depth [depth]`: number of commits to traverse.
- `-w`, `--words ["w1,w2"]`: comma-separated bug-fix keywords.
- `-r`, `--regex [regex]`: custom bug-fix regex.
- `--exclude-path [regex]`: exclude changed file paths matching the regex.
- `--display-timestamps`: include commit timestamps in output.

When `-c` is specified, only `-b` and `--exclude-path` can be used together.
`-d`, `-w`, `-r`, and `--display-timestamps` are rejected in cyclomatic
complexity mode.

When `--both` is specified, only `-b` and `--exclude-path` can be used together.
`-d`, `-w`, `-r`, `--display-timestamps`, and `-c` are rejected in combined mode.

`--both` uses the default hotspot bug-fix regex and scans the full selected
branch history.

In this repository, `bugspots` will automatically use `.venv/bin/python3` for
`-c` and `--both` when that virtualenv exists.

## Example Output

```bash
$ cd /your/git/repo
$ git bugspots -d 500

  .. example output ..

	Scanning /git/eventmachine repo
	Found 31 bugfix commits, with 23 hotspots:

	Fixes:
		- Revert "Write maximum of 16KB of data to an SSL connection per tick (fixes #233)" for #273
		- Do not close attached sockets (fixes #200)
		- Write maximum of 16KB of data to an SSL connection per tick (fixes #233)
		- Merge branch 'master' into close_schedule_fix
		- Remove dependency on readbytes.rb for ruby 1.9 (fixes #167, #234)
		- Fix compilation on MSVC2008 (fixes #253)
		- EM::Deferrable#(callback|errback|timeout) now return self so you can chain them (closes #177)
		- Make EventMachine::Connection#get_peername and #get_sockname valid for IPv6 (closes #132)
		- reconnect DNS socket if closed
		- Use String#bytesize in EM::Connection#send_datagram for 1.9 (closes #153)
		- Fix an issue that would cause the EM process to block when the loopbreak pipe filled up (closes #158)
		- namespace std is already included, so just call min(). fixes vc6 issue with min macro
		- Use close() instead of closesocket() to prevent FD leaks on windows.
		- Stop advertising non-available authentication mechanisms, allow multi-line authentication - fixes compatibility with javamail
		- typo fixes and undef fstat for ruby on Windows
		- Deprecate now aged info, as it's fixed
		- Some fixes for Solaris and Nexenta (opensolaris kernel + linux userland)
		- Some fixes for solaris
		- Minor fixes for rbx compatibility
		- Reduce the size of the RunEpollOnce stack frame by 800kb. This fixes the long-standing epoll+threads issue (#84)
		- Fixed aggregated event handling for kqueue and notify, fixed path for ifconfig.
		- More win32 fixes
		- Added test for reactor_thread? and fixed up EM.schedule for pre-reactor schedules
		- Merge branch 'master' of git@github.com:eventmachine/eventmachine
		- Use read instead of recv in ConnectionDescriptor::Read (fixes EM.attach issues with pipes)
		- Use false to indicated a cancelled timer instead of using an empty proc. Reduces mem usage in certain situations.
		- Inotify fixes: file_delete only fires after fds have been closed, use syscall hackery for older linux distributions (*cough* debian)
		- Clean up deferrable.rb: fixed rdoc, alias method wrappers, remove unnecessary forwardable
		- More solaris build fixes.
		- More solaris build issues fixed
		- fixed a small bug with basic auth (cherry-pick conflict merge from mmmurf (closes #92))

	Hotspots:
		0.9723 - ext/ed.cpp
		0.3311 - ext/ed.h
		0.3271 - ext/em.cpp
		0.3034 - lib/eventmachine.rb
		0.2433 - lib/em/protocols/postgres3.rb
		0.2403 - ext/project.h
		0.0431 - lib/em/deferrable.rb
		0.029 - ext/cmain.cpp
		0.0278 - ext/rubymain.cpp
		0.0277 - ext/eventmachine.h
		0.0241 - lib/em/resolver.rb
		0.0241 - tests/test_resolver.rb
		0.0225 - lib/em/connection.rb
		0.0013 - lib/em/protocols/smtpserver.rb
		0.0003 - ext/extconf.rb
		0.0002 - tests/test_basic.rb
		0.0001 - ext/em.h
		0.0001 - ext/cplusplus.cpp
		0.0001 - ext/fastfilereader/extconf.rb
		0.0 - lib/em/filewatcher.rb
		0.0 - tests/test_file_watch.rb
		0.0 - ext/fastfilereader/mapper.cpp
		0.0 - lib/protocols/httpclient.rb
```

Cyclomatic complexity mode:

```bash
$ bugspots /your/git/repo -c

	Scanning /your/git/repo repo
	Found 2 files with cyclomatic complexity:

	Cyclomatic Complexity:
		7 (2 functions) - main.go
		4 (1 functions) - web/app.ts
```

Combined mode:

```bash
$ bugspots /your/git/repo --both

	Scanning /your/git/repo repo
	Found 3 files with combined scores:

	Combined Scores:
		2.1000 (hotspot: 0.3000, cyclomatic: 7, functions: 2) - main.go
		0.0000 (hotspot: 0.0000, cyclomatic: 4, functions: 1) - only_complexity.ts
		0.0000 (hotspot: 0.5000, cyclomatic: 0, functions: 0) - ruby_only.rb
```

## Development

Install dependencies:

```bash
bundle install
```

Run lint:

```bash
bundle exec rake lint
```

Run tests:

```bash
bundle exec rake test
```

Run dependency audit:

```bash
bundle exec bundler-audit check --update
```

## CI

GitHub Actions runs the following checks on pushes and pull requests:

- Dependency audit with `bundler-audit`
- Lint with `rubocop`
- Test execution with `rake test`

## Security

Dependency vulnerability scanning is part of CI. If you find a security issue,
please report it privately rather than opening a public issue first.

## License

MIT License. Copyright (c) 2011 Ilya Grigorik.

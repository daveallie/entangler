<p align="center" style="width: 50px;"><img src="https://vignette1.wikia.nocookie.net/pokemon/images/e/ef/114Tangela_Dream.png/revision/latest/scale-to-width-down/185?cb=20141203054028"/></p>
<h1 align="center">Entangler</h1>

[![Build Status](https://travis-ci.org/daveallie/entangler.svg?branch=master)](https://travis-ci.org/daveallie/entangler)

Syncing tool used to keep a local and remote (over SSH) folder in sync.

## Installation

```
$ gem install entangler
```

## Usage

```shell
$ entangler master /some/base/path user@remote:/some/remote/path
```

```
$ entangler -h
Entangler v1.3.2

Usage:
   entangler master <base_dir> <remote_user>@<remote_host>:<remote_base_dir> [options]
   entangler master <base_dir> <other_synced_base_dir> [options]

Options:
    -i, --ignore '.git'              Ignore path when syncing, string is regex if surrounded by '/'
                                     All paths should be relative to the base sync directory.
    -p, --port PORT                  Overwrite the SSH port (usually 22)
                                     (doesn't do anything in slave mode)
    -c, --config PATH                Use a custom SSH config (usually $HOME/.ssh/config)
                                     (doesn't do anything in slave mode)
        --force-polling              Forces the use of the listen polling adapter
                                     (works cross-platform, generally slower, doesn't do anything in slave mode)
        --no-rvm                     Skip attempting to load RVM on remote
    -v, --verbose                    Log Debug lines
    -q, --quiet                      Don't log to stdout in master process
        --version                    Show version number
    -h, --help                       Show this message
```

### Ignoring files and folders

If you specify a string, instead of a regex, it will match any path starting with that string, i.e. `-i '.git'` will ignore the `.git`
folder and all its sub-directories. If you want to just ignore the the `.git` sub-directories but not the content in the git folder, you'll
have to use regex. `-i '/^\.git(?:\/[^\/]+){2,}$/'` will match all sub-directories of `.git/`, but not the files in `.git`.

You can specify multiple `-i` or `--ignore` flags to ignore multiple paths.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/daveallie/entangler. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

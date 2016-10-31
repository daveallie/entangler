# Entangler

Syncing tool used to keep a local and remote (over SSH) folder in sync.

## Prerequisites
  - librsync 2.x

## Installation

```
$ gem install entangler
```

## Usage

```shell
entangler master /some/base/path user@remote:/some/remote/path

entangler -h
Usage:
   entangler master <base_dir> <remote_user>@<remote_host>:<remote_base_dir> [options]
   entangler slave <base_dir> [options]

Options:
    -p, --port PORT                  Overwrite the SSH port (usually 22)
                                     (doesn't do anything in slave mode)
    -v, --version                    Show version number
    -h, --help                       Show this message
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/daveallie/entangler. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

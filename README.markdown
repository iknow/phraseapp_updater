# PhraseAppUpdater

[![Build Status](https://travis-ci.org/iknow/phraseapp_updater.svg?branch=master)](https://travis-ci.org/iknow/phraseapp_updater)

**Version** 0.1.0

This is a tool for performing three-way merges of [PhraseApp](https://phraseapp.com) locale data with locale data commited to your application.

Our current workflow has localizers working on a `master` project on
PhraseApp. This regularly gets pulled into the `master` branch of our
application and released. This branch is for "maintenance" localizations:
ongoing translations of existing locale keys.

However, we also introduce, remove, and change locale data by merging in
feature branches to `master`. When we do this, we want to update the
`master` PhraseApp project with the data newly-commited to our `master`
branch. PhraseApp provides [APIs](https://phraseapp.com/docs/api/v2/) and a [Ruby gem](https://github.com/phrase/phraseapp-ruby) for accessing
them, but the API only allows either a) completely overwriting
PhraseApp's data or b) reapplying PhraseApp's data on top of the
uploaded data.

What we want instead is a three way merge where the uploaded data wins
on conflict. Non-conflicting changes on PhraseApp are preserved, while
changes on both sides take the committed data. The result of the merge
is then sent to PhraseApp, keeping it up-to-date with the newest commit
of `master`.

This is especially important when removing keys. Imagine we have the
following, no-longer useful key:

```json
unused:
  one: An unused
```

On PhraseApp, we've added another plural form:


```json
unused:
  one: An unused
  zero: No unused's
```

And in our feature branch, we remove it. The result we want is that the
key completely disappears, instead of getting a result like either of
the above.

## Installation

This gem provides a command line interface for performing the
merge and uploading the result to PhraseApp. To use it, install the gem:

`gem install phraseapp_updater`

You may also use this gem programatically from your own application.

Add this line to your application's Gemfile:

```ruby
gem 'phraseapp_updater'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install phraseapp_updater

## Usage

CLI
---

`phraseapp_updater` operates on two directories and your PhraseApp API
data. The two directories should contain the previous revision of your
locale files and the latest revision of the same files. These will be
used in the merge with the files on PhraseApp.

The main command is the the `push_changes` command:

```
phraseapp_updater push_changes --new_locales_path="/data/previous", --previous_locales_path="/data/new" --phraseapp_api_key="yourkey" --phraseapp_project_id="projectid"
```

The arguments provided to the command can also be specified as shell
variables:

```
PA_NEW_LOCALES_PATH
PA_PREVIOUS_LOCALES_PATH
PA_API_KEY
PA_PROJECT_ID
```

Ruby
---

`PhraseAppUpdater.push` is analogous to the command line version:

```ruby
PhraseAppUpdater.push("api_key", "project_id", "previous/path", "current/path")
```

## Future Improvements

If you'd like to contribute, these would be very helpful!

* Expose the changed files on the command line
* Implement other `LocaleFile`s with `parse` for non-JSON types
* Checking if PhraseApp files changed during execution before upload, to reduce the race condition window
* More specs for the API and shell

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. When everything is working, make a pull request.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iknow/phraseapp_updater. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


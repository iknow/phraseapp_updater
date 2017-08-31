# PhraseAppUpdater

[![Build Status](https://travis-ci.org/iknow/phraseapp_updater.svg?branch=master)](https://travis-ci.org/iknow/phraseapp_updater)

**Version** 0.1.6

This is a tool for merging PhraseApp locale data with locale data
committed in your project.

It can perform three-way merges of [PhraseApp](https://phraseapp.com) locale data with locale data commited to your application.
It can also pull from PhraseApp, ignoring missing keys (this is very
useful for using "unverified" status for marking a translation as a
draft).

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

What we want instead is a three way merge where the committed data wins
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

**Push**

`phraseapp_updater push` operates on two directories and your PhraseApp API
data. The two directories should contain the previous revision of your
locale files from PhraseApp and the latest revision of the same files
committed to your application's respository.  These will be used in the
merge with the files on PhraseApp.

```
phraseapp_updater push --new_locales_path="/data/previous", --previous_locales_path="/data/new" --phraseapp_api_key="yourkey" --phraseapp_project_id="projectid --file_format=json"
```

The arguments provided to the command can also be specified as shell
variables:

```
PA_NEW_LOCALES_PATH
PA_PREVIOUS_LOCALES_PATH
PA_API_KEY
PA_PROJECT_ID
PA_FILE_FORMAT
```

Additionally, PhraseApp credentials can be loaded from a
`.phraseapp.yml` file, specified with `--config-file-path`

**Pull**

`phraseapp_updater pull` pulls data down from your PhraseApp project.
However, when keys are missing from the PhraseApp data, it restores them
(if present) from the files at fallback path provided. This allows you
to mark keys as "unverified" on PhraseApp, meaning you don't pull in
draft translations, while allowing you to keep the current version of
that translation.

If you want to pull without this fallback behavior, PhraseApp's [client](https://phraseapp.com/docs/developers/cli/)
is the best tool to use.

```
phraseapp_updater pull --fallback_path="/data/app/locales" --phraseapp_api_key="yourkey" --phraseapp_project_id="projectid --file_format=json""
```

The PhraseApp data passed to the command can also be specified as shell
variables:

```
PA_API_KEY
PA_PROJECT_ID
PA_FILE_FORMAT
```

Additionally, PhraseApp credentials can be loaded from a
`.phraseapp.yml` file, specified with `--config-file-path`

Ruby
---

`PhraseAppUpdater.push` and `PhraseAppUpdater.pull` are analogous to the command line versions:

```ruby
PhraseAppUpdater.new("api_key", "project_id", "file_format").push("previous/path", "current/path")
PhraseAppUpdater.new("api_key", "project_id", "file_format").pull("fallback/path")
```


## git-based Driver

We use a small bash script for driving this library to push and pull
from PhraseApp. While there are many ways to merge data in your
application with PhraseApp, this works for us:

https://gist.github.com/kevingriffin/d59821446ce424a56c7da2686d4ae082

## Future Improvements

If you'd like to contribute, these would be very helpful!

* Separating downloading and resolving data from PhraseApp from pushing
  back up to it, to enable different kinds of workflows.
* Expose the changed files on the command line.
* Implement other `LocaleFile`s with `parse` for non-JSON types.
* Checking if PhraseApp files changed during execution before upload, to reduce the race condition window.
* More specs for the API and shell.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. When everything is working, make a pull request.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iknow/phraseapp_updater. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


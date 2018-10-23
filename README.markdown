# PhraseAppUpdater

[![Build Status](https://travis-ci.org/iknow/phraseapp_updater.svg?branch=master)](https://travis-ci.org/iknow/phraseapp_updater)

**Version** 2.0.0

This is a tool for managing synchronization between locale data in
[PhraseApp](https://phraseapp.com) and committed in your project. It can perform
JSON-aware three-way merges with respect to a common ancestor, and maintains a
record of the common ancestor on PhraseApp using tags.

Our workflow considers localization data stored on PhraseApp to be a working
copy for a given branch. We expect developers working on the code and
translators working on PhraseApp to both be able to make changes and have them
integrated.

PhraseApp provides [APIs](https://phraseapp.com/docs/api/v2/) and a [Ruby
gem](https://github.com/phrase/phraseapp-ruby) for accessing them, but the API
only allows either a) completely overwriting PhraseApp's data with local data or
b) reapplying PhraseApp's data on top of the local data. Neither of these cases
is appropriate for integrating changes made on both sides.

What we want instead is a three way merge where the committed data wins on
conflict. Non-conflicting changes on PhraseApp are preserved, while changes to
the same key on both sides take the committed data. The result of the merge is
then applied to both sides, keeping them up to date with each other.

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

And in our feature branch, we remove it. The result we want is that the key
completely disappears, instead of getting a result like either of the above.

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

**Setup**

`phraseapp_updater setup` creates and initializes a PhraseApp project
corresponding to your branch. It must be provided with the current git revision
of the branch and the path to the locale files.

```
phraseapp_updater setup --phraseapp_project_name="yourbranch" --parent_commit="yourhash" --phraseapp_api_key=yourkey" path_to_locales
```

**Synchronize**

`phraseapp_updater synchronize` synchronizes a git remote branch with its
corresponding PhraseApp project, incorporating changes from each side into the
other. If both sides were changed, a three-way merge is performed. The result is
uploaded to PhraseApp and committed and pushed to the git remote as appropriate.

The option `--no_commit` may be provided to restrict changes to the PhraseApp
side. If specified, then in the case that the branch was modified, the merge
result will be uploaded to PhraseApp and the common ancestor updated to the
branch head.

```
phraseapp_updater synchronize <checkout_path>
```

**Download**

`phraseapp_updater download` downloads and normalizes locale files from
PhraseApp, saving them to the specified location. The revision of the recorded
common ancestor is printed to standard out.

```
phraseapp_updater download --phraseapp_project_id="yourid" --phraseapp_api_key="yourkey" target_path
```

**Upload**

`phraseapp_updater upload` uploads normalized locale files from your branch to
PhraseApp and resets the recorded common ancestor to the specified revision.

```
phraseapp_updater upload --phraseapp_project_id="yourid" --phraseapp_api_key="yourkey" path_to_locales
```

**Update Parent Commit**
`phraseapp_updater update_parent_commit` records a new common ancestor on
PhraseApp without changing the locales.

```
phraseapp_updater update_parent_commit --phraseapp_project_id="yourid" --phraseapp_api_key="yourkey" --parent_commit="yourhash"
```

**Merge**

`phraseapp_updater merge` performs a content-aware three-way merge between
locale files in three directories: `ancestor_path`, `our_path`, and
`their_path`. In the case of conflicts, the changes from `our_path` are
accepted. The results are normalized and written to the path specified with
`to`.

```
phraseapp_updater merge ancestor_path our_path their_path --to target_path
```


**Diff**

Performs a content-aware diff between locale files in two directories. Returns
with exit status 1 or 0 to signal differences or no differences respectively

```
phraseapp_updater diff path1 path2
```


## git-based Driver

We use a small bash script for driving this library to push and pull
from PhraseApp. While there are many ways to merge data in your
application with PhraseApp, this works for us:

https://gist.github.com/kevingriffin/d59821446ce424a56c7da2686d4ae082

## Future Improvements

If you'd like to contribute, these would be very helpful!

* We'd like to use "unverified" translations on PhraseApp as the equivalent of
  an unstaged working copy. For this to work, we need to be able to recover
  previous translations at the same key. While PhraseApp doesn't itself keep
  this history, we could do this by restoring the absent keys from the diff
  between verified and unverified download from the common ancestor.
* Expose the changed files on the command line.
* Checking if PhraseApp files changed during execution before upload, to reduce the race condition window.
* More specs for the API and shell.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. When everything is working, make a pull request.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iknow/phraseapp_updater. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


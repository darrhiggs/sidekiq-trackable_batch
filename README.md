# Sidekiq::TrackableBatch

`Sidekiq::TrackableBatch` is an extension to `Sidekiq::Batch` that provides access to detailed, up-to-date progress information about a `Sidekiq::Batch` as it runs.

## Installation

Add the following to your application's Gemfile:

```ruby
gem 'sidekiq-trackable_batch'
#	and either
gem 'sidekiq-pro'
#	or
gem 'sidekiq-batch'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-trackable_batch

## Usage

`Sidekiq::TrackableBatch` inherits from `Sidekiq::Batch` allowing you to create and setup a `Sidekiq::TrackableBatch` exactly as you would with `Sidekiq::Batch`:

```ruby
trackable_batch = Sidekiq::TrackableBatch.new
#	set callbacks & description etc as required
trackable_batch.jobs
#	enqueue some background work
end
```

All `Sidekiq::Batch` features should continue to work as before:

```ruby
Sidekiq::Batch::Status.new(trackable_batch.bid)
trackable_batch.invalidate_all
# …
```

### Basic

Given the following worker:

```ruby
class MyWorker
  include Sidekiq::TrackableBatch::Worker # also includes sidekiq worker
  def self.max; 76; end # your job's max gets added to the batch total
  def perform(*args)
    sleep 1
    update_status(value: 31) # update the job's status at any point
    sleep 1.5
    update_status(value: 76)
  end
end
```

When a `Sidekiq::TrackableBatch` is setup as above, with two `MyWorker` jobs.

Then the following API can be used to access progress data:

```ruby
tracking = Sidekiq::TrackableBatch.track(trackable_batch)
tracking.to_h # => { max: 152, value: 62 }
# if a value is not yet known, a nil will be returned in its place.
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sidekiq-trackable_batch.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


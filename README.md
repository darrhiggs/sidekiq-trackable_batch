# Sidekiq::TrackableBatch

`Sidekiq::TrackableBatch` is an extension to `Sidekiq::Batch` that provides access to detailed, up-to-date progress information about a `Sidekiq::Batch` as it runs.

## Installation

Add the following to your application's Gemfile:

```ruby
gem 'sidekiq-trackable_batch'
#	and either
gem 'sidekiq-pro'
#	or
gem 'sidekiq-batch' # currently unsupported
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-trackable_batch

## Usage

Add a `.max` to existing workers:
```ruby
class MyWorker
  def self.max; 42; end # some (total) amount of work
end
```

Update the class' `#perform` method to use `#update_status`:
```ruby
def perform(*args)
  # do some work
  update_status(value: 21) # made available through Sidekiq::Worker
  # maybe do some more work
  update_status(value: self.class.max, status_text: 'Done')
end
```

Create a batch using `Sidekiq::TrackableBatch`:
```ruby
trackable_batch = Sidekiq::TrackableBatch.new
#  set callbacks & description etc as required
trackable_batch.jobs
  5.times { MyWorker.perform_async }
end
```

Track your batch:
```ruby
Sidekiq::TrackableBatch::Tracking(trackable_batch).to_h
# => { max: 210, value: 105 }
```

All `Sidekiq::Batch` features should continue to work as before:
```ruby
Sidekiq::Batch::Status.new(trackable_batch.bid)
trackable_batch.invalidate_all
# …
```

### Really Complex Workflows with Batches

`Sidekiq::TrackableBatch` is constrained by all jobs having to be exposed to the batch during initialization. To fulfil this constraint, an updated DSL has been provided to allow nested batch creation that requires ordered execution:
```ruby
trackable_batch = Sidekiq::TrackableBatch.new do # Pass a block
  # The :update callback has the same API as existing
  # Sidekiq::Batch callbacks 
  on(:update, OrderStatusNotifier, order_id: order.id)
  
  # updates can be pushed to another queue other than the default
  self.update_queue = 'priority'

  # The DSL consists of three (aliased) chainable methods:
  # #start_with, #then and #finally. As with a callback, a target
  # can be passed (#on_update is called by default). 
  # A block can be passed for inline declaration.
  start_with('pick', 'Fulfilment#pick', products: order.products)
  .then('pack', 'Fulfilment#pack', boxes: order.boxes)
  .finally('ship', 'Fulfilment#ship', boxes: order.boxes)
  # The first argument will be set as the batch's description.
  
  # Optionally set an initial state
  initial_status(status_text: 'Order sent for picking')
  
   # Sidekiq::Batch methods are also available 
   on(:complete, 'Fulfilment#fulfilment_complete', order_id: order.id)
end
```
All commands, their arguments and return values are documented, and available on [rdoc.info][docs] 

## DEMO

Check out the [demo app][da] ([source][dar]) to see how the [Really Complex Workflows with Batches][rcwwb] example would be created in a Rails 5 app using `Sidekiq::TrackableBatch`. The app specifically demonstrates how batch updates can be consumed through the use of the new `:update` callback, and uses ActionCable to asynchronously stream these updates to a client.

## Caveats
- ActiveJob is unsupported. [(wiki)][saj#c]
- #update_status only accepts strings to be set for anything except the value.

## TODOS
- Integrate with sidekiq UI.
- Provide mountable rack middleware à la Sidekiq Pro.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec appraisal rake` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sidekiq-trackable_batch.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

[da]: https://sidekiq-trackable-batch-demo.herokuapp.com/
[dar]: https://github.com/darrhiggs/sidekiq_trackable_batch_demo_app
[docs]: TODO
[rcwwb]: https://github.com/mperham/sidekiq/wiki/Really-Complex-Workflows-with-Batches
[saj#c]: https://github.com/mperham/sidekiq/wiki/Active-Job#commercial-features

require "sidekiq/trackable_batch/version"

begin
  require 'sidekiq-pro'
rescue LoadError
  begin
    require 'sidekiq/batch'
  rescue LoadError
    raise LoadError, 'Neither Sidekiq::Pro nor Sidekiq::Batch are available. ' \
      'Ensure one of these libraries is made available to Sidekiq::TrackableBatch'
  end
end

module Sidekiq
  module TrackableBatch
    # Your code goes here...
  end
end

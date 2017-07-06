# frozen_string_literal: true
require 'sidekiq/trackable_batch/persistance'

module Sidekiq
  # Provides access to #update_status in classes that include Sidekiq::Worker
  module Worker
    include Sidekiq::TrackableBatch::Persistance
    # @private
    alias _update_status update_status

    # @example Update a batch's status
    #   class MyWorker
    #     include Sidekiq::Worker
    #     def max; 100; end
    #     def perform(*)
    #       update_status(value: 100, more: 'info')
    #     end
    #   end
    #
    # @param [Hash] updates The changes to be persisted to the
    #   {TrackableBatch}'s current status
    # @option updates [Numeric] :value Amount to increment the
    #   current value by.
    # @option updates [String] * Any other key and value updates. (optional)
    def update_status(**updates)
      _update_status(batch, **updates)
    end
  end
end

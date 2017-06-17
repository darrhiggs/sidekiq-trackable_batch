module Sidekiq
  class TrackableBatch < Sidekiq::Batch
    # Include this module into a worker class that is to be tracked
    # as part of a TrackableBatch
    module Worker
      class << self
        # Includes Sidekiq::Worker into the receiver
        # @api private
        def included(base)
          base.include Sidekiq::Worker
        end
      end

      # @example Make a Worker trackable
      #   class MyWorker
      #     include Sidekiq::TrackableBatch::Worker
      #     def max; 100; end
      #     def perform(*)
      #       update_status(value: 100)
      #     end
      #   end
      #
      # @param [Hash] updates The changes to be persisted to the
      #   TrackableBatch's current status
      # @option updates [Numeric] :value Amount to increment the
      #   current value by
      def update_status(**updates)
        tracking = Tracking.new(bid).to_h
        key = "TB:#{bid}:STATUS"
        Sidekiq.redis do |c|
          c.hset key, 'value', tracking[:value].to_i + updates.fetch(:value, 0)
          c.expire key, TTL
        end
      end
    end
  end
end

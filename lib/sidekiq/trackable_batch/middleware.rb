# frozen_string_literal: true
module Sidekiq
  class TrackableBatch < Batch
    module Middleware
      # @api private
      class Client
        def call(worker_class, msg, _queue, _redis_pool)
          trackable_batch = Thread.current[:tbatch]
          if trackable_batch
            msg['max'] = Object.const_get(worker_class).max
            out = yield
            trackable_batch.register_job(out) if out
            return out
          end
          yield
        end
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::TrackableBatch::Middleware::Client
  end
end

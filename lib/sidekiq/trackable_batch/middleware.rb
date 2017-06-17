module Sidekiq
  class TrackableBatch < Batch
    module Middleware
      # @api private
      class Client
        def call(worker_class, msg, _queue, _redis_pool)
          if Thread.current[:tbatch]
            msg['max'] = worker_class.constantize.max
            Thread.current[:tbatch].register_job_enqueue(msg)
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

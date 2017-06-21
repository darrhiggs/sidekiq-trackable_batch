# frozen_string_literal: true
require 'sidekiq'
require 'sidekiq/scheduled'

Sidekiq.logger.level = Logger::WARN

REDIS_URL = 'redis://localhost/15'
REDIS = Sidekiq::RedisConnection.create(url: REDIS_URL)
Sidekiq.redis = { url: REDIS_URL }

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sidekiq/trackable_batch'

middleware = if Sidekiq::NAME == 'Sidekiq Pro'
               Sidekiq::Batch::Server
             else
               Sidekiq::Batch::Middleware::ServerMiddleware
             end

Sidekiq.server_middleware { |c| c.add middleware }

Dir[File.join(__dir__, 'support/**/*.rb')].each { |f| require f }

require 'sidekiq/testing'
Sidekiq::Testing.fake!

Sidekiq::Testing.server_middleware { |c| c.add middleware }

require 'minitest/autorun'

Minitest.after_run do
  Sidekiq.redis(&:flushall)
end

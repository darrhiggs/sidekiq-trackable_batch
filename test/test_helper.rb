$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sidekiq/trackable_batch'

require 'minitest/autorun'

Sidekiq.logger.level = Logger::ERROR

require 'sidekiq/redis_connection'
REDIS_URL = 'redis://localhost/15'.freeze
REDIS = Sidekiq::RedisConnection.create(url: REDIS_URL)

Sidekiq.redis = { url: REDIS_URL }

require 'sidekiq/testing'
Sidekiq::Testing.fake!

Minitest.after_run do
  Sidekiq.redis(&:flushall)
end

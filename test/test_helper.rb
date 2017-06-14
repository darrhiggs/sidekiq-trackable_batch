$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sidekiq/trackable_batch'

require 'minitest/autorun'

require 'sidekiq/testing'
Sidekiq::Testing.fake!

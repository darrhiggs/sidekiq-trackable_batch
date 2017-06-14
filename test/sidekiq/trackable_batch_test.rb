require 'test_helper'

class Sidekiq::TrackableBatchTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Sidekiq::TrackableBatch::VERSION
  end

  class MyWorker
    include Sidekiq::TrackableBatch::Worker
    def self.max; 76; end
    def perform(*args)
      update_status(value: 31)
    end
  end

  def test_basic_usage
    tb = Sidekiq::TrackableBatch.new
    tb.jobs do
      2.times { MyWorker.perform_async }
    end
    tracking = Sidekiq::TrackableBatch::tracking(tb)

    MyWorker.drain

    assert_equal({max: 152, value: 62}, tracking.to_h)
  end
end

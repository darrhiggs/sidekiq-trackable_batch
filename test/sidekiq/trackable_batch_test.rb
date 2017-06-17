require 'test_helper'

Sidekiq::Testing.server_middleware do |chain|
  if Sidekiq::NAME != 'Sidekiq Pro'
    chain.add(Sidekiq::Batch::Middleware::ServerMiddleware)
  end
end

module Sidekiq
  class TrackableBatchTest < Minitest::Test
    def test_that_it_has_a_version_number
      name = 'sidekiq-trackable_batch.gemspec'
      gemspec = Gem::Specification.load(name)
      refute_nil gemspec.version
    end

    class MyWorker
      include Sidekiq::TrackableBatch::Worker
      def self.max
        76
      end

      def perform(*)
        update_status(value: 31)
      end
    end

    def test_basic_usage
      tb = Sidekiq::TrackableBatch.new
      jids = tb.jobs do
        2.times { MyWorker.perform_async }
      end

      assert(jids.length, 2)

      MyWorker.drain

      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 152, value: 62 }, tracking.to_h)
    end

    def test_batch_max_updates_as_job_are_enqueued
      tb = Sidekiq::TrackableBatch.new
      tb.jobs do
        2.times { MyWorker.perform_async }
      end
      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 152, value: nil }, tracking.to_h)
    end

    def test_work_is_tracked_when_batch_is_reopened_to_add_jobs
      tb = Sidekiq::TrackableBatch.new
      tb.jobs { 2.times { MyWorker.perform_async } }

      dup_tb = Sidekiq::TrackableBatch.new(tb.bid)
      dup_tb.jobs { 2.times { MyWorker.perform_async } }

      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 304, value: nil }, tracking.to_h)
    end
  end
end

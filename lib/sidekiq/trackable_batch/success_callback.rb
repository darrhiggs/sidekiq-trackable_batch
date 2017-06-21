# frozen_string_literal: true
require 'sidekiq/trackable_batch/persistance'

module Sidekiq
  class TrackableBatch < Batch
    # @api private
    class SuccessCallback
      include Persistance

      def on_success(_, next_stage_bid)
        jobs = get_jobs(next_stage_bid)
        Sidekiq::Client.new.raw_push(
          jobs.map { |j| Sidekiq.load_json(j) }
        )
      end
    end
  end
end

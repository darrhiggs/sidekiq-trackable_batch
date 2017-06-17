module Sidekiq
  class TrackableBatch < Batch
    # Access TrackableBatch progress data.
    class Tracking
      # @param (see TrackableBatch#initialize)
      def initialize(bid)
        @status_key = "TB:#{bid}:STATUS"
      end

      # @return [Hash] the TrackableBatch's current progress
      def to_h
        {
          max: status[:max].to_i,
          value: status[:value] ? status[:value].to_i : nil
        }
      end

      private

      def status
        Sidekiq.redis do |c|
          c.hgetall @status_key
        end.symbolize_keys
      end
    end
  end
end

begin
  require 'sidekiq-pro'
rescue LoadError
  begin
    require 'sidekiq/batch'
  rescue LoadError
    raise LoadError, 'Neither Sidekiq::Pro nor Sidekiq::Batch are available. ' \
      'Ensure one of these libraries is made available to ' \
      'Sidekiq::TrackableBatch'
  end
end

require 'sidekiq/trackable_batch/middleware'
require 'sidekiq/trackable_batch/tracking'
require 'sidekiq/trackable_batch/worker'

module Sidekiq
  # Interface for creating and tracking Sidekiq TrackableBatches
  class TrackableBatch < Sidekiq::Batch
    # @api private
    module JobLifeCycleEvents
      def register_job_enqueue(msg)
        messages << msg.symbolize_keys
      end

      private

      def messages
        @messages ||= []
      end
    end

    include JobLifeCycleEvents
    # Time to live for data persisted to redis (30 Days)
    TTL = 60 * 60 * 24 * 30

    class << self
      # Track a TrackableBatch
      # @param trackable_batch [TrackableBatch] Instance
      # @return [Tracking] Instance
      def track(trackable_batch)
        Tracking.new(trackable_batch.bid)
      end
    end

    # Create a new TrackableBatch
    # @param bid [String] An existing Batch ID
    def initialize(bid = nil)
      @reopened = bid
      super(bid)
      key_base = "TB:#{bid || self.bid}"
      @keys = {
        jids: "#{key_base}:JIDS",
        status: "#{key_base}:STATUS"
      }
      @status = @reopened ? Tracking.new(bid).to_h : {}
    end

    # @param (see Sidekiq::Batch#jobs)
    def jobs
      Thread.current[:tbatch] = self
      @jids = super
      persist_batch
      @jids
    ensure
      Thread.current[:tbatch] = nil
    end

    private

    # rubocop:disable Metrics/AbcSize
    def persist_batch
      max_increment = messages.map { |m| m[:max] }.inject(:+)
      max = @status[:max].to_i
      Sidekiq.redis do |c|
        c.multi do
          c.sadd @keys[:jids], @jids
          c.expire @keys[:jids], TTL

          c.hset @keys[:status], 'max', max + max_increment
          c.expire @keys[:status], TTL
        end
      end
    end
    # rubocop:enable Metrics/AbcSize
  end
end

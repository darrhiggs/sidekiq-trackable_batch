# frozen_string_literal: true
require 'sidekiq/trackable_batch/scripting'

module Sidekiq
  class TrackableBatch < Sidekiq::Batch
    # @api private
    # Interface for Redis persistance
    module Persistance
      include Scripting

      private

      def get_status(bid)
        connection { |c| c.hgetall keys(bid)[:status] }
      end

      def get_jobs(bid)
        connection { |c| c.smembers keys(bid)[:jobs] }
      end

      def persist_batch(batch)
        status = get_status(batch.bid)
        new_max = batch.messages.max_sum + status['max'].to_i

        connection do |c|
          keys = keys(batch.bid)
          c.multi do
            c.hset keys[:status], :max, new_max
            c.expire keys[:status], TTL

            unless batch.messages.empty?
              c.sadd keys[:jobs], batch.messages.to_json
              c.expire keys[:jobs], TTL
            end

            if batch.update_listeners
              c.set keys[:update_listeners], batch.update_listeners.to_json
              c.expire keys[:update_listeners], TTL
              if batch.update_queue
                c.set keys[:update_queue], batch.update_queue
                c.expire keys[:update_queue], TTL
              end
            end

            c.hgetall keys[:status]
          end
        end
      end

      # Updates the status of a {TrackableBatch} with provided updates.
      # - If the key `value` is provided the value will be incremented by that amount.
      # - All other keys will create or replace a string value equal to the key's value.
      # Also enqueues any update callbacks that have been registered.
      def update_status(batch, updates = {})
        parent_bid = batch.parent_bid
        keys = if parent_bid
                 [
                   keys(parent_bid)[:status],
                   keys(batch.bid)[:status],
                   keys(parent_bid)[:update_listeners],
                   keys(parent_bid)[:update_queue]
                 ]
               else
                 [
                   nil,
                   keys(batch.bid)[:status],
                   keys(batch.bid)[:update_listeners],
                   keys(batch.bid)[:update_queue]
                 ]
               end

        update_queue, update_listeners = Sidekiq.load_json(
          connection do |c|
            c.evalsha(
              @@sha,
              keys: keys,
              argv: [updates.delete(:value), Sidekiq.dump_json(updates), TTL]
            )
          end
        )

        return unless update_listeners

        Thread.new do # clean thread
          Sidekiq::Client.push_bulk(
            'queue' => update_queue,
            'class' => Sidekiq::TrackableBatch::UpdateNotifier,
            'args' => update_listeners.map do |update_listener|
              target, args = update_listener.first
              [parent_bid || batch.bid, target, args]
            end
          )
        end.join
      end

      def keys(bid)
        {
          jobs: "TB:#{bid}:JOBS",
          status: "TB:#{bid}:STATUS",
          update_listeners: "TB:#{bid}:UPDATE_LISTENERS",
          update_queue: "TB:#{bid}:UPDATE_QUEUE"
        }
      end

      def connection
        Sidekiq.redis do |connection|
          yield connection
        end
      end
    end
  end
end

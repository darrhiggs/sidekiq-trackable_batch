# frozen_string_literal: true
module Sidekiq
  class TrackableBatch < Batch
    # @api private
    class UpdateNotifier
      include Sidekiq::Worker

      def perform(bid, target, args)
        tracking = Tracking.new(bid).to_h
        klass, method = target.split('#')
        Object.const_get(klass).new.send(
          method || :on_update,
          tracking,
          args.reduce({}) { |m, (k, v)| m.merge k.to_sym => v }
        )
      end
    end
  end
end

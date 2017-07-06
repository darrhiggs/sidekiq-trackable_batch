# frozen_string_literal: true
require 'sidekiq/trackable_batch/persistance'

module Sidekiq
  class TrackableBatch < Batch
    # Access TrackableBatch progress data (status).
    class Tracking
      include Persistance

      # @param (see TrackableBatch#initialize)
      def initialize(bid)
        @bid = bid
      end

      # Get the current status of a {TrackableBatch} as a hash. (network request)
      # @return [Hash] the {TrackableBatch}'s current status
      def to_h
        status = get_status(@bid).reduce({}) { |m, (k, v)| m.merge k.to_sym => v }
        {
          max: status.delete(:max).to_i,
          value: status[:value] ? status.delete(:value).to_i : nil,
          **status
        }
      end
    end
  end
end

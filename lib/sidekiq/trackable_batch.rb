begin
  require 'sidekiq-pro'
rescue LoadError
  begin
    require 'sidekiq/batch'
  rescue LoadError
    raise LoadError, 'Neither Sidekiq::Pro nor Sidekiq::Batch are available. ' \
      'Ensure one of these libraries is made available to Sidekiq::TrackableBatch'
  end
end

require 'sidekiq/trackable_batch/worker'

module Sidekiq
  class TrackableBatch < Sidekiq::Batch
    class << self
      def tracking(trackable_batch)
      end
    end
  end
end

module Sidekiq
  class TrackableBatch < Sidekiq::Batch
    module Worker
      class << self
        def included(base)
          base.include Sidekiq::Worker
        end
      end
      def update_status(**kargs); end
    end
  end
end

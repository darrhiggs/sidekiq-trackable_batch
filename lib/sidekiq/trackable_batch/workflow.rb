# frozen_string_literal: true
module Sidekiq
  class TrackableBatch < Batch
    # @api private
    class Workflow
      attr_reader :stages

      def initialize(enclosing_batch)
        @enclosing_batch = enclosing_batch
        @stages = []
      end

      def <<(stage)
        @stages << stage
      end

      def stage(name)
        @stages.detect { |stage| stage.description == name }
      end

      def start
        Sidekiq::Client.new.raw_push(@stages.first.job_list)
      end

      def setup(&block)
        @enclosing_batch.instance_eval(&block)
        setup_callbacks
        setup_jobs
      end

      private

      def setup_jobs
        @enclosing_batch.jobs do
          @stages.each do |stage|
            stage.setup(@enclosing_batch)
          end
        end
      end

      def setup_callbacks
        @stages.each_cons(2) do |stage, next_stage|
          stage.on(:success, SuccessCallback, next_stage.bid)
        end
      end
    end
  end
end

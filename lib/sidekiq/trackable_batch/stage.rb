# frozen_string_literal: true
module Sidekiq
  class TrackableBatch < Batch
    # @api private
    class Stage < TrackableBatch
      attr_reader :job_list

      def initialize(description, target, **kwargs, &block)
        self.description = description
        if target.respond_to?(:include?) && target.include?('#')
          @target = target
        end
        @kwargs = kwargs
        @block = block
        @job_list = []
        super(&nil)
      end

      def setup(enclosing_batch)
        if @target
          klass, method = @target.split('#')
          Object.const_get(klass).new.send(method, self, **@kwargs)
        end
        instance_exec(**@kwargs, &@block) if @block
        job_list.each { |job| enclosing_batch.register_job(job) }
      end
    end
  end
end

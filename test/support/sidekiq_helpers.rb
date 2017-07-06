# frozen_string_literal: true
require 'sidekiq/api'
require 'sidekiq/exception_handler'

module Sidekiq
  module TestHelpers
    include ExceptionHandler

    def drain_callbacks(queue: 'default')
      drain(queue: queue)
      q = Sidekiq::Queue.new(queue)
      return unless q.first && q.first.display_class =~ /Sidekiq/
      drain_callbacks(queue: queue)
    end

    def drain(queue: 'default')
      $threads = []
      q = Sidekiq::Queue.new(queue)
      perform_one(queue: queue) while q.size != 0
      $threads.map(&:join)
    end

    def perform_one(queue: 'default')
      msg = Sidekiq.load_json(Sidekiq.redis { |c| c.rpop("queue:#{queue}") })
      worker = Object.const_get(msg['class'])
      perform_async(worker, msg, queue)
    end

    def perform_async(worker, msg, queue)
      $threads << Thread.new { perform(worker, msg, queue) }
    end

    def perform(worker_class, msg, queue)
      worker = worker_class.new
      worker.jid = msg['jid'] # see: https://github.com/mperham/sidekiq/blob/f49b4f11db9620ff6969b2d394edd45ab6b72688/lib/sidekiq/processor.rb#L129
      Sidekiq.server_middleware.invoke(worker, msg, queue) do
        worker.perform(*msg['args'])
      end
    rescue => ex
      handle_exception(ex, context: 'Job raised exception', job: msg)
    end
  end
end

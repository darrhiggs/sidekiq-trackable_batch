# frozen_string_literal: true
require 'sidekiq/client'

module Sidekiq
  # @api private
  class Client
    alias _raw_push raw_push

    def raw_push(payload)
      if Thread.current[:tbatch]
        Thread.current[:tbatch].job_list << payload.pop
        true
      else
        _raw_push(payload)
      end
    end
  end
end

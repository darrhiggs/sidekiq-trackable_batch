# frozen_string_literal: true
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

require 'sidekiq/overrides/client'
require 'sidekiq/overrides/worker'
require 'sidekiq/trackable_batch/middleware'
require 'sidekiq/trackable_batch/messages'
require 'sidekiq/trackable_batch/persistance'
require 'sidekiq/trackable_batch/stage'
require 'sidekiq/trackable_batch/success_callback'
require 'sidekiq/trackable_batch/tracking'
require 'sidekiq/trackable_batch/update_notifier'
require 'sidekiq/trackable_batch/workflow'

module Sidekiq
  # Interface for creating and tracking Sidekiq TrackableBatches
  class TrackableBatch < Batch
    include Persistance

    # Time to live for data persisted to redis (30 Days)
    TTL = 60 * 60 * 24 * 30

    class << self
      # Track a {TrackableBatch}
      # @param trackable_batch [TrackableBatch] Instance
      # @return [Tracking] Instance
      def track(trackable_batch)
        Tracking.new(trackable_batch.bid)
      end
    end

    attr_reader :messages, :update_listeners, :workflow
    attr_accessor :update_queue

    # Create a new TrackableBatch
    # @param bid [String] An existing Batch ID
    def initialize(bid = nil, &block)
      @reopened = bid
      @messages = Messages.new
      super(bid)
      return unless block_given?
      @workflow = Workflow.new(self)
      @workflow.setup(&block)
      @workflow.start
    end

    # @private
    # @return [true, false]
    def reopened?
      !@reopened.nil?
    end

    # @private
    def register_job(msg)
      @messages << msg
    end

    # Register a callback for a {TrackableBatch}'s status updates
    #
    # @example Using a class that responds to #on_update
    #   trackable_batch = Sidekiq::TrackableBatch.new
    #   trackable_batch.on(:update, Klass)
    #
    # @example Using a string to set a specific callback method.
    #   trackable_batch = Sidekiq::TrackableBatch.new do
    #     on(:update, 'Klass#not_on_update', more: 'information')
    #   end
    #
    # @param [Symbol] event The name of the event
    # @param [Class, String] target The class and an optionally declared update method
    #   (defaults to #on_update)
    # @param [Hash] options Any extra information required to be passed to the callback
    def on(event, target, options = {})
      if event == :update
        @update_listeners ||= []
        @update_listeners << { target => options }
      else
        super
      end
    end

    # Chainable DSL for creating a Sidekiq::TrackableBatch with nested
    # batches that require ordered execution.
    #
    # @example
    #   class Klass
    #     def pack(nested_batch)
    #       nested_batch.jobs do
    #         MyWorker.perform_async
    #       end
    #     end
    #
    #     def ship(nested_batch, options)
    #       nested_batch.jobs do
    #         MyWorker.perform_async(options)
    #       end
    #     end
    #   end
    #
    #   trackable_batch = Sidekiq::TrackableBatch.new do
    #     start_with('Pick', options: :get, passed: :along) do |options|
    #       jobs do
    #         MyWorker.perform_async(options[:passed])
    #       end
    #     end
    #     .then('Pack', 'Klass#pack')
    #     .finally('Ship', 'Klass#ship', here: :also)
    #   end
    #
    # @param [String] description The nested batch's description
    # @param [String] target Class and method to call to setup the nested batch
    #   (required if no block is provided)
    # @param [Hash] args Arguments to be forwarded to block or target
    # @param [Block] block Block that executes in the context of the nested batch
    #   (required if no target is provided)
    #
    # @return receiver
    def then(description, target = nil, **args, &block)
      raise ArgumentError unless target || block
      @workflow << Stage.new(description, target, **args, &block)
      self
    end
    alias start_with then
    alias finally then

    # @param (see Sidekiq::Batch#jobs)
    # @return [Array<String>] A list of JIDs for work that has been enqueued
    def jobs
      Thread.current[:parent_tbatch] = Thread.current[:tbatch]
      Thread.current[:tbatch] = self
      @jids = super
      persist
      @jids
    ensure
      Thread.current[:tbatch] = Thread.current[:parent_tbatch]
      Thread.current[:parent_tbatch] = nil
    end

    # Set extra information in a batch's initial status
    # @example Add some status text to a batch before any work is performed
    #   trackable_batch = Sidekiq::TrackableBatch.new
    #   trackable_batch.initial_status(status_text: 'Starting')
    #   tracking = Sidekiq::TrackableBatch.track(trackable_batch)
    #   tracking.to_h # => { max: nil, value: nil, status_text: 'Starting' }
    #
    # @param options [Hash]
    def initial_status(options = {})
      update_status(self, options)
    end

    private

    def persist
      persist_batch(self)
      @messages.clear
    end
  end
end

require 'sidekiq/trackable_batch/initializer'

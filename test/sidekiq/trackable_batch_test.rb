# frozen_string_literal: true
require 'test_helper'

module Sidekiq
  class TrackableBatchTest < Minitest::Test
    include TestHelpers

    def test_that_it_has_a_version_number
      name = 'sidekiq-trackable_batch.gemspec'
      gemspec = Gem::Specification.load(name)
      refute_nil gemspec.version
    end

    def test_basic_usage
      tb = Sidekiq::TrackableBatch.new
      jids = tb.jobs do
        2.times { MyWorker.perform_async }
      end

      assert(jids.length, 2)

      MyWorker.drain

      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 152, value: 62 }, tracking.to_h)
    end

    def test_batch_max_updates_as_job_are_enqueued
      tb = Sidekiq::TrackableBatch.new
      tb.jobs do
        2.times { MyWorker.perform_async }
      end
      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 152, value: nil }, tracking.to_h)
    end

    def test_work_is_tracked_when_batch_is_reopened_to_add_jobs # [0]
      tb = Sidekiq::TrackableBatch.new
      tb.jobs { 2.times { MyWorker.perform_async } }
      tb.jobs { 2.times { MyWorker.perform_async } }

      dup_tb = Sidekiq::TrackableBatch.new(tb.bid)
      dup_tb.jobs { 2.times { MyWorker.perform_async } }

      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 456, value: nil }, tracking.to_h)
    end

    def test_initial_status_can_be_set
      tb = Sidekiq::TrackableBatch.new
      tb.initial_status foo: :bar

      tracking = Sidekiq::TrackableBatch.track(tb)

      assert_equal({ max: 0, value: nil, foo: 'bar' }, tracking.to_h)
    end

    def test_advanced_usage
      Sidekiq::Testing.disable! do
        params = {
          products: [
            { id: 1, name: 'product_1', volume: 10 },
            { id: 3, name: 'product_3', volume: 36 },
            { id: 2, name: 'product_2', volume: 12 }
          ],
          gift_wrap: true
        }
        order = Order.create(params[:products])

        trackable_batch = Sidekiq::TrackableBatch.new do
          on(:update, MyNotifier, order_id: order.id)
          on(:update, 'MyNotifier#notify', order_id: order.id)
          self.update_queue = 'updates'
          start_with 'pick', products: order.products do |products:|
            jobs do
              products.each { |product| Picker.perform_async(product[:id]) }
            end
          end
          .then('pack', 'Fulfilment#pack', gift_wrap: params[:gift_wrap], order: order)
          .then('ship', boxes: order.boxes_required) do |boxes:|
            on(:success, 'Fulfilment#ship_success', some: :args)
            jobs do
              boxes.times { Shipper.perform_at(Courier.next_collection) }
            end
          end
          .finally('finish') do
            jobs do
              Finisher.perform_async
            end
          end
        end

        assert_equal(
          trackable_batch.workflow.stages.map(&:description),
          %w(pick pack ship finish)
        )
        assert_equal trackable_batch.workflow.stage('ship').description, 'ship'

        tracking = Sidekiq::TrackableBatch.track(trackable_batch)

        max = [
          picker_max = order.products.count * Picker.max,
          gift_wrap_boxer_max = order.boxes_required * GiftWrapBoxer.max,
          order.boxes_required * Shipper.max,
          finisher_max = Finisher.max
        ].reduce(:+)

        assert_equal({ max: max, value: nil }, tracking.to_h)
        assert_nil($status)

        drain # Picker jobs
        assert_equal({ max: max, value: picker_max }, tracking.to_h)
        assert_equal(Sidekiq::Queue.new('updates').size, 6)

        drain(queue: 'updates')
        assert_equal(
          { max: max, value: picker_max, order_id: order.id },
          $status
        )

        drain_callbacks # Picker

        drain # GiftWrapBoxer jobs
        assert_equal(
          { max: max, value: picker_max + gift_wrap_boxer_max },
          tracking.to_h
        )

        drain(queue: 'updates')
        assert_equal(
          {
            max: max,
            value: picker_max + gift_wrap_boxer_max,
            order_id: order.id
          },
          $status
        )

        drain_callbacks # GiftWrapBoxer

        Time.stub :now, DateTime.now.next_month.to_time do
          Sidekiq::Scheduled::Enq.new.enqueue_jobs
          drain # Shipper jobs
          assert_equal({ max: max, value: max - finisher_max }, tracking.to_h)
        end

        drain(queue: 'updates')
        assert_equal(
          { max: max, value: max - finisher_max, order_id: order.id },
          $status
        )

        drain_callbacks # Shipper
        assert_equal($ship_success_call_args, 'some' => 'args')

        drain # Finisher
        assert_equal(
          { max: max, value: max, **Finisher.updates },
          tracking.to_h
        )

        drain(queue: 'updates')
        assert_equal(
          { max: max, value: max, order_id: order.id, **Finisher.updates },
          $status
        )

        drain_callbacks # Finisher & Enclosing batch
        assert_equal(Sidekiq::Queue.new.size, 0)
      end
    end
  end
end
# [0] Drop support for this:  See: https://github.com/mperham/sidekiq/issues/3130

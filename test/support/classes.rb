# frozen_string_literal: true
require 'securerandom'

module Courier
  def self.next_collection
    # 09:00, 7 days a week
    require 'date'
    now = DateTime.now
    if now.hour > 9
      tomorrow = now.next_day
      DateTime.commercial(tomorrow.cwyear, tomorrow.cweek, tomorrow.cwday, 9).to_time - Time.now
    else
      DateTime.commercial(now.cwyear, now.cweek, now.cwday, 9).to_time - Time.now
    end
  end
end

class Fulfilment
  def pack(stage, args)
    stage.jobs do
      args[:order].boxes_required.times do
        if args[:gift_wrap]
          GiftWrapBoxer.perform_async
        else
          Boxer.perform_async
        end
      end
    end
  end

  def ship_success(_status, args)
    $ship_success_call_args = args
  end
end

class Order
  attr_reader :products
  BOX_VOLUME = 25

  def self.create(products)
    new(products)
  end

  def id
    @id ||= SecureRandom.uuid
  end

  def initialize(products)
    @products = products
  end

  def boxes_required
    volumes = products.map { |product| product[:volume] }
    packaged_seperately = volumes.reduce([]) do |memo, volume|
      volume >= BOX_VOLUME ? memo << volume : memo
    end
    for_boxing = volumes - packaged_seperately
    (for_boxing.map(&:to_f).reduce(:+) / BOX_VOLUME).ceil + packaged_seperately.count
  end
end

class Picker
  include Sidekiq::Worker
  def self.max
    45
  end

  def perform(*)
    update_status(value: 45)
  end
end

class Boxer
  include Sidekiq::Worker
  def self.max
    10
  end

  def perform
    update_status(value: 10)
  end
end

class GiftWrapBoxer
  include Sidekiq::Worker
  def self.max
    12
  end

  def perform
    update_status(value: 12)
  end
end

class Shipper
  include Sidekiq::Worker
  def self.max
    15
  end

  def perform
    update_status(value: 15)
  end
end

class Finisher
  include Sidekiq::Worker
  def self.max
    1
  end

  def self.updates
    { complete: 'true' }
  end

  def perform
    update_status(value: 1, **self.class.updates)
  end
end

class MyNotifier
  def on_update(tracking, options)
    $status = tracking.to_h.merge(options)
  end
  alias notify on_update
end

class MyWorker
  include Sidekiq::Worker
  def self.max
    76
  end

  def perform(*)
    update_status(value: 31)
  end
end

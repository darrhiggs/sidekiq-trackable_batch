# frozen_string_literal: true

# @private
class Messages
  def initialize
    @messages = []
  end

  def <<(msg)
    @messages << msg
  end

  def max_sum
    @messages.reduce(0) { |memo, msg| memo + msg['max'] }
  end

  def empty?
    @messages.empty?
  end

  def to_json
    @messages.map(&:to_json)
  end

  def clear
    @messages.clear
  end
end

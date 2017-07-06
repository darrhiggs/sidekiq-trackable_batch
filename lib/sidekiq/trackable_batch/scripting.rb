# frozen_string_literal: true
module Sidekiq
  class TrackableBatch < Sidekiq::Batch
    # @api private
    module Scripting
      SCRIPT = <<-LUA
        local function hgetall(key)
          local out = redis.call('HGETALL', key)
          local result = {}
          for i = 1, #out, 2 do
            result[out[i]] = out[i + 1]
          end
          return result
        end

        local function merge_flat_dicts(base, updates)
          local ret = {}
          for k,v in pairs(base) do ret[k] = v end
          for k,v in pairs(updates) do ret[k] = v end
          return ret
        end

        local function dict_to_array(dict)
          local ret = {}
          for k,v in pairs(dict) do
            table.insert(ret, k)
            table.insert(ret, tostring(v))
          end
          return ret
        end

        local function update_batch_status(key, next_value, other_updates, ttl)
          local other_updates = cjson.decode(other_updates)
          local status = hgetall(key)
          if tonumber(next_value) ~= nil then
            redis.pcall('HSET', key, 'value', tonumber(status['value'] or 0) + tonumber(next_value))
          end
          if next(other_updates) ~= nil then
            local status = hgetall(key)
            redis.pcall('HMSET', key, unpack(dict_to_array(merge_flat_dicts(status, other_updates))))
          end
          redis.pcall('EXPIRE', key, ttl)
        end

        local parent_key, batch_key, update_listeners_key, update_queue_key = unpack(KEYS);
        local next_value, other_updates, ttl = unpack(ARGV);

        local ret = {}

        update_batch_status(batch_key, next_value, other_updates, ttl)
        if parent_key then update_batch_status(parent_key, next_value, other_updates, ttl) end

        ret[1] = redis.pcall('GET', update_queue_key)

        local update_listeners = redis.pcall('GET', update_listeners_key)
        if update_listeners then
          ret[2] = cjson.decode(update_listeners)
        end

        return cjson.encode(ret)
      LUA
      class << self
        def load_script
          Sidekiq.redis do |c|
            @@sha = c.script(:load, SCRIPT)
          end
        end
      end
    end
  end
end

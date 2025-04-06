local Threads = require 'threads'
-- local Trace = require("trace")
local gc_metatable = require 'gc_metatable'

local Flock = {}

local function new(thread_count)
  -- Trace.debug("Creating a Flock of %d threads", thread_count)
  local pool = Threads.Threads(thread_count)

  local function map(user_fn, data, ...)
    local args = { ... }
    local input_data_result_mapping = {}
    local map_results = {}

    for i, value in ipairs(data) do
      local result_mapping = {
        input = value,
        result = nil,
      }

      table.insert(input_data_result_mapping, i, result_mapping)
    end

    for i, value in ipairs(data) do
      pool:addjob(function()
        unpack = table.unpack or unpack
        return user_fn(value, unpack(args))
      end, function(result)
        input_data_result_mapping[i].result = result
      end)
    end

    pool:synchronize()

    for i, result in pairs(input_data_result_mapping) do
      table.insert(map_results, result.result)
    end

    return map_results
  end

  local function map_reduce(user_fn, reduce_fn, data, ...)
    return reduce_fn(map(user_fn, data, ...))
  end

  local function close()
    if pool then
      -- Trace.debug("Terminating Flock of %d threads", thread_count)
      pool:terminate()
      pool = nil
    end
  end

  local flock = {
    map = map,
    map_reduce = map_reduce,
    close = close,
  }

  gc_metatable(flock, close)

  return flock
end

function Flock.taskq(thread_count, map_fn, ...)
  -- Trace.debug('Creating a taskq of %d threads', thread_count)

  local args = { ... }

  local pool
  local success, err = pcall(function()
    pool = Threads.Threads(thread_count)
  end)
  if not success then
    -- Trace.crit('taskq creation of %d threads failed', thread_count)
    os.exit(12)
  end

  local pending_jobs = 0
  local last_result

  local completion_fn = function(result)
    last_result = result
  end
  local enqueue_job = function(x)
    pending_jobs = pending_jobs + 1
    pool:addjob(function()
      unpack = table.unpack or unpack
      return map_fn(x, unpack(args))
    end, completion_fn)
  end

  local dequeue_job = function()
    local result
    if pending_jobs > 0 then
      pool:dojob()
      pending_jobs = pending_jobs - 1
      result = last_result
      last_result = nil
    end
    return result
  end

  local taskq = {
    enqueue_job = enqueue_job,
    dequeue_job = dequeue_job,
  }

  local function close()
    if pool then
      -- Trace.debug('Terminating taskq of %d threads', thread_count)
      pool:terminate()
      pool = nil
    end
  end

  gc_metatable(taskq, close)

  return taskq
end

function Flock.new(thread_count)
  local flock
  local success, err = pcall(function()
    flock = new(thread_count)
  end)
  if not success then
    Trace.crit('flock creation of %d threads failed', thread_count)
    os.exit(12)
  end
  return flock
end

return Flock

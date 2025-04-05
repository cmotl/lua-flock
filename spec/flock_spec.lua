expose("Flock requires global state", function()
  Flock = require("flock")

  local reduce = function(results)
    local sum = 0
    for _, result in ipairs(results) do
        sum = sum + result
    end
    return sum
  end

  describe("flock", function()

    it("can map-reduce inside a map-reduce", function()
      local sum_map = function(x)
        local Flock = require("flock")
        return Flock.new(10).map_reduce(function(x) return x*x end, reduce, x)
      end

      assert.is.equal(110, Flock.new(10).map_reduce(sum_map, reduce, {{1,2,3,4,5}, {1,2,3,4,5}}))
    end)

    describe("map", function()

      it("should map values", function()
        assert.is.same({1,4,9,16,25}, Flock.new(2).map(function(x) return x*x end, {1,2,3,4,5}))
      end)

      it("should accept additional parameters that are passed into the user provided function", function() 
        local map_fn = function(x, y, z) return string.format("%d, %d, %s", x, y, z) end
        local result = Flock.new(2).map(map_fn, {1,2}, 42, "a")

        assert.is.same({"1, 42, a", "2, 42, a"}, result)
      end)
    end)

    describe("map_reduce", function()
      it("should map and then reduce values", function()
        assert.is.equal(55, Flock.new(10).map_reduce(function(x) return x*x end, reduce, {1,2,3,4,5}))
      end)

      it("should accept additional parameters that are passed into the user provided function", function() 
        local reduce = function(x) return x end 
        local map_fn = function(x, y, z) return string.format("%d, %d, %s", x, y, z) end
        local result = Flock.new(2).map(map_fn, {1,2}, 42, "a")
                       Flock.new(10).map_reduce(map_fn, reduce, {1,2}, 42, "a")

        assert.is.same({"1, 42, a", "2, 42, a"}, result)
      end)
    end)

    describe("taskq", function()

      local map_fn
      local taskq

      before_each(function()
        map_fn = function(x) return x end
        taskq = Flock.taskq(5, map_fn)
      end)

      it("should dequeue nil if nothing has been enqueued", function()
        assert.is.equal(nil, taskq.dequeue_job())
      end)

      it("should dequeue single enqueued value", function()
        taskq.enqueue_job(5)

        assert.is.equal(5, taskq.dequeue_job())
      end)

      it("should dequeue multiple enqueued values", function()
        local results = {}

        taskq.enqueue_job(5)
        taskq.enqueue_job(6)

        table.insert(results, taskq.dequeue_job())
        table.insert(results, taskq.dequeue_job())
        table.sort(results)

        assert.is.same({5,6}, results)
      end)

      it("should accept additional parameters that are passed into the user provided function", function() 
        map_fn = function(x, y, z) return string.format("%d, %d, %s", x, y, z) end
        taskq = Flock.taskq(5, map_fn, 42, "a")

        taskq.enqueue_job(5)

        result = taskq.dequeue_job()

        assert.is.equal("5, 42, a", result)
      end)
    end)
  end)
end)

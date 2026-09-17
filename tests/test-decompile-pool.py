"""Exercise the actual pool with a deterministic cooperative task scheduler."""
from pathlib import Path
import subprocess
import os
import shutil

root = Path(__file__).resolve().parent.parent
source_path = root / "saveinstance.luau"
source = source_path.read_text(encoding="utf-8")
source = source[source.index("-- BEGIN DECOMPILE WORKER POOL"):source.index("-- END DECOMPILE WORKER POOL")]
mock = r'''
local clockState = { now = 0 }
local os = { clock = function() return clockState.now end }
local task
local function scheduler(cancelWorks)
    clockState = { now = 0 }
    local pending, serial = {}, 0
    local runtime = { cancelCalls = 0 }
    local function resume(thread, ...)
        local ok, delay = coroutine.resume(thread, ...)
        assert(ok, tostring(delay))
        if coroutine.status(thread) ~= "dead" then
            serial += 1
            pending[thread] = { at = clockState.now + (delay or 0.01), serial = serial }
        end
    end
    task = {
        spawn = function(fn, ...)
            local thread = coroutine.create(fn)
            resume(thread, ...)
            return thread
        end,
        wait = function(delay) return coroutine.yield(delay or 0.01) end,
        cancel = function(thread)
            runtime.cancelCalls += 1
            if cancelWorks == "throws" then error("native cancellation unavailable") end
            if cancelWorks ~= false then pending[thread] = nil; coroutine.close(thread) end
        end,
    }
    function runtime.pump(untilTime, done)
        local iterations = 0
        while true do
            if done and done() then return end
            local target, first
            for thread, item in pairs(pending) do
                if not first or item.at < first.at or (item.at == first.at and item.serial < first.serial) then
                    target, first = thread, item
                end
            end
            if not target or first.at > untilTime then return end
            pending[target] = nil
            clockState.now = math.max(clockState.now, first.at)
            resume(target)
            iterations += 1
            assert(iterations < 100000, "scheduler runaway")
        end
    end
    return runtime
end
'''
tests = r'''
local checks = 0
local function run(jobs, options, invoke, onComplete, onProgress, cancelWorks)
    local runtime = scheduler(cancelWorks)
    local result
    task.spawn(function() result = RunDecompileJobs(jobs, options, invoke, onComplete, onProgress) end)
    runtime.pump(1000, function() return result ~= nil end)
    assert(result, "pool did not return")
    checks += 1
    return result, runtime
end
local empty = run({}, {}, function() error("unexpected") end)
assert(empty.completed == 0 and empty.maxActive == 0 and not empty.aborted)

local order, progressTimes = {}, {}
local normal = run({0.3, 0.1, 0.2, 0.4, 0.05, 0.1}, {}, function(delay, index)
    task.wait(delay)
    return "source " .. index
end, function(_, record, index)
    assert(record.status == "succeeded")
    table.insert(order, index)
end, function(snapshot)
    table.insert(progressTimes, clockState.now)
    assert(snapshot.active <= 4 and #snapshot.currentScripts == snapshot.active)
    assert(snapshot.eta == nil or snapshot.eta >= 0)
end)
assert(normal.succeeded == 6 and normal.completed == 6 and normal.maxActive == 4)
assert(normal.elapsed < 0.6 and order[1] == 2 and order[2] == 5)
for i = 2, #progressTimes do assert(progressTimes[i] - progressTimes[i-1] >= 0.1 - 1e-9) end
for i = 1, 6 do assert(normal.results[i].source == "source " .. i) end

for _, value in ipairs({0/0, math.huge, -math.huge, -1, 0, 0.5, "2"}) do
    assert(not pcall(RunDecompileJobs, {}, {concurrency=value}, function() return "ok" end))
end
for _, key in ipairs({"timeout", "maxTime"}) do
    for _, value in ipairs({0/0, math.huge, -math.huge, -2, 0, "2"}) do
        assert(not pcall(RunDecompileJobs, {}, {[key]=value}, function() return "ok" end))
    end
end
assert(not pcall(RunDecompileJobs, {}, {maxTime=-1}, function() return "ok" end))
local fraction = run({1,2,3,4}, {concurrency=2.9}, function() task.wait(0.1);return "ok" end)
assert(fraction.concurrency == 2 and fraction.maxActive == 2)
local capped = run({1,2,3,4,5,6,7,8,9}, {concurrency=900}, function() task.wait(0.1);return "ok" end)
assert(capped.concurrency == 8 and capped.maxActive == 8)

local invalid = run({"throws", "nil", "empty", "number", "ok"}, {}, function(kind)
    if kind == "throws" then error("native failure") end
    if kind == "nil" then return nil end
    if kind == "empty" then return "" end
    if kind == "number" then return 7 end
    return "source"
end)
assert(invalid.failed == 4 and invalid.succeeded == 1 and not invalid.aborted)
assert(string.find(invalid.results[1].error, "native failure", 1, true))

for _, cancellation in ipairs({true, false, "throws"}) do
    local writes = 0
    local hung, runtime = run({1,2,3,4,5,6}, {concurrency=2,timeout=0.25}, function()
        task.wait(1)
        return "late source"
    end, function() writes += 1 end, nil, cancellation)
    assert(hung.aborted and hung.reason == "job_timeout" and hung.attempted == 2)
    assert(hung.completed == 0 and hung.timedOut == 2 and hung.results[3].status == "not_started")
    assert(hung.results[1].status == "timed_out" and runtime.cancelCalls == 2)
    runtime.pump(2)
    assert(writes == 0 and hung.completed == 0 and hung.attempted == 2, "late completion escaped closed gate")
end

local blocking = run({1,2}, {timeout=0.25}, function()
    clockState.now += 0.5 -- native blocks the scheduler, then eventually returns
    return "too late"
end)
assert(blocking.timedOut == 1 and blocking.attempted == 1 and blocking.completed == 0)

local whole = run({1,2,3}, {timeout=-1,maxTime=0.3,concurrency=2}, function()
    task.wait(5)
    return "late"
end)
assert(whole.aborted and whole.reason == "max_time" and whole.attempted == 2 and whole.timedOut == 0)
assert(whole.results[1].status == "cancelled" and whole.results[3].status == "not_started")

local callback = run({1,2,3,4}, {concurrency=2}, function()
    task.wait(0.1)
    return "ok"
end, function() error("cache callback failed") end)
assert(callback.aborted and callback.reason == "callback_error" and #callback.callbackErrors == 1)
assert(callback.callbackErrors[1].callback == "onComplete" and callback.attempted == 2)
local progressFailure = run({1,2}, {}, function() return "ok" end, nil, function() error("UI failed") end)
assert(progressFailure.aborted and progressFailure.reason == "callback_error" and progressFailure.attempted == 0)
assert(progressFailure.callbackErrors[1].callback == "onProgress")
local rejected, rejectedRuntime = run({1,2,3,4,5}, {concurrency=2,abortOnError=function(err)
    if string.find(err, "[Oracle HTTP 429]", 1, true) then return "oracle_rate_limit" end
end}, function(_, index)
    task.wait(index == 1 and 0.1 or 1)
    if index == 1 then error("[Oracle HTTP 429]") end
    return "late paid result"
end, function() error("aborted completions must not cache") end, nil, false)
assert(rejected.aborted and rejected.reason == "oracle_rate_limit" and rejected.attempted == 2)
assert(rejected.failed == 1 and rejected.results[1].status == "failed" and rejected.results[2].status == "cancelled")
rejectedRuntime.pump(2)
assert(rejected.completed == 1 and rejected.succeeded == 0 and #rejected.callbackErrors == 0)
local ordinary = run({1,2}, {abortOnError=function() return nil end}, function(_, index)
    if index == 1 then error("ordinary malformed bytecode") end
    return "ok"
end)
assert(not ordinary.aborted and ordinary.failed == 1 and ordinary.succeeded == 1)
local policyFailure = run({1,2}, {abortOnError=function() error("policy failed") end}, function() error("bad") end)
assert(policyFailure.aborted and policyFailure.callbackErrors[1].callback == "abortOnError")
print("decompile pool: " .. checks .. " scenarios passed (bounded concurrency, validation, results, deadlines, callbacks, late native returns)")
'''

generated = root / "tests/.generated-pool.luau"
generated.write_text(mock + source + tests, encoding="utf-8")
subprocess.run([os.environ.get("LUAU_COMPILE", shutil.which("luau-compile") or "luau-compile"), str(source_path)], check=True, stdout=subprocess.DEVNULL)
subprocess.run([os.environ.get("LUAU", shutil.which("luau") or "luau"), str(generated)], check=True)

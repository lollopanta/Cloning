-- RUN STATISTICS: SaveInstance 420 Edition tracks execution data for robloxscripts.com (Script Ops).
-- Each run sends SaveInstance's version, Roblox's version, your executor, the game's ids, device and OS
-- type, start-up time, and counts of the SaveInstance features used and errors hit, then checks in
-- every 5 minutes while the game runs. It never sends your Roblox user id, name or display name, the
-- server's JobId or hardware ids. The reporter runs on its own thread: if robloxscripts.com is down,
-- saving still works.
-- Turn it off: set getgenv().RSOPS_OFF = true before loading SaveInstance, or create the file
-- rsops/optout.txt in your executor's workspace. Details: https://robloxscripts.com/script-ops
local ops = setmetatable({ id = "ops_2tlgdq6bpr5k", ref = "6a23e92ced790a687ae2c801", version = __SSI_VERSION }, { q = {}, __index = function(t, k) return function(...) local q = getmetatable(t).q; if q and #q < 64 then q[#q + 1] = { k, ... } end end end });
task.spawn(pcall, function() local g = getgenv and getgenv() or {}; if g.RSOPS_OFF == true or g.RSOps and g.RSOps._off == true or isfile and select(2, pcall(isfile, "rsops/optout.txt")) == true then return end; loadstring(game:HttpGet("https://robloxscripts.com/ops/v1.lua"))(ops) end);

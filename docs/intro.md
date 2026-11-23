---
sidebar_position: 1
title: Make your first save
---

# Make your first save

## 1. Load and run

Run this in your executor while in a game:

```lua
local saveinstance = loadstring(game:HttpGet(
    "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
))()

saveinstance()
```

The panel at the bottom of the screen shows each stage: decompiling scripts, then saving instances. Stay in the game until it says **Saved**. A big game (hundreds of thousands of instances, thousands of scripts) takes a few minutes, mostly decompiling.

The console prints a summary when it finishes:

```text
[SaveInstance] scripts: 5005 decompiled, 907 reused, 5 failed, 74 server-only, 14 without source
[SaveInstance] saved Blox Fruits - 2753915549 - 2026-11-23 19.32.47.rbxlx: 167018 instances, 177.7 MB in 4m 46s
```

## 2. Find the file

Look in your executor's `workspace` folder. The name is the place name, place id and UTC time:

```text
Blox Fruits - 2753915549 - 2026-11-23 19.32.47.rbxlx
```

Set `FilePath = "My save"` for a fixed name instead (no extension; an existing file with that name is replaced).

Open the file in Roblox Studio. Check a building near you, something far away, the terrain and a few scripts. A finished save means the file was written; it does not prove the client had the whole map (see [streaming](./streaming)).

`ServerStorage.SaveInstance420` holds a README and anything saved by the extras options.

## 3. Adjust the next save

| You want | Use |
|---|---|
| The rest of a streaming map | `SetStreaming = true`, see [Load streamed regions](./streaming) |
| Only the map, fast | `Decompile = false` |
| One model | `saveinstance(workspace.TheModel)` |
| Your player's GUI and tools | `IsolateLocalPlayer = true` |
| Things parented to nil | `NilInstances = true` |
| A log to share | `Debug = true`, then send `SaveInstance420/debug <time>.log` |

Every setting is in the [options reference](./options).

## Save a model

Pass the instance itself, not its name:

```lua
saveinstance(workspace:WaitForChild("YourModel"))
```

This writes `YourModel - <place id> - <time>.rbxmx`. Several at once:

```lua
saveinstance({ workspace.BuildingA, workspace.BuildingB }, { FilePath = "Two buildings" })
```

## Use the result in a script

```lua
local result = saveinstance({ Decompile = false, ShowStatus = false })
if result.ok then
    print("saved", result.path, result.instances, "instances")
else
    warn("save failed:", result.error)
end
```

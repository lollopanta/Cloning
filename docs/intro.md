---
sidebar_position: 1
title: Make your first save
---

# Make your first save

## 1. Load and run

Copy this into your executor, change any value, and run it while in a game. Left as is, it saves the whole place with decompiled scripts; every line shows the default and what the other choice does.

```lua
-- SaveInstance 420 Edition: change the values below, then run this in your executor while in a game.
-- Every option: https://pages.sirmemegithub.com/SaveInstance420Edition/docs/options/

-- getgenv().RSOPS_OFF = true -- remove the "--" at the start to turn off run statistics for robloxscripts.com

local saveinstance = loadstring(game:HttpGet(
    "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
))()

saveinstance({
    -- What to save
    Mode = "optimized",             -- "full": every service | "scripts": only what holds scripts
    NilInstances = false,           -- true: also save instances parented to nil
    RemovePlayerCharacters = true,  -- false: keep player characters in Workspace
    IsolateLocalPlayer = false,     -- true: also save your PlayerGui, Backpack, ...

    -- Scripts
    Decompile = true,               -- false: skip decompiling (much faster, map only)

    -- StreamingEnabled games
    SetStreaming = false,           -- true: load the rest of the map before saving
    StreamingAreaSize = 10000,      -- size of the area to load around you, in studs

    -- Output
    FilePath = false,               -- "My save": fixed file name (no extension)
    ShowStatus = true,              -- false: hide the progress panel
    NeutralizeLighting = false,     -- true: reset dark or foggy lighting before saving
    SafeMode = false,               -- true: disconnect from the server before writing the file
    Debug = false,                  -- true: write a log to SaveInstance420/ in your workspace
})
```

SaveInstance tracks execution data (run statistics) for robloxscripts.com: versions, executor, game ids and counts of the features used, never your account name or id. To turn it off, run `getgenv().RSOPS_OFF = true` before the loader. See [Run statistics and privacy](./privacy).

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

This writes `YourModel - <place id> - <time>.rbxmx`. If the instance does not exist (for example `FindFirstChild` returned nil), `saveinstance` raises an error instead of saving the whole place. Several at once:

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

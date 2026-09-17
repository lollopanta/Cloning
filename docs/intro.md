---
sidebar_position: 1
title: Make your first save
---

# Make your first save

Start with the default export. Once you have a file that opens in Studio, add the options your place needs.

## 1. Load and run

Run this in your executor. It loads the current script from SirMeme's self-hosted repository and writes a place file.

```lua
local saveinstance = loadstring(game:HttpGet(
    "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
))()

saveinstance({
    FilePath = "My place",
    SafeMode = false,
    Debug = true,
})
```

The status panel shows the current stage. Leave the client connected until it reports that the save is finished.

**Normal script decompilation is already on.** Streaming requests and the concurrent decompile prepass are off until you enable them. `SafeMode=false` keeps the normal connected save path; turning it on changes the client state.

## 2. Find the file

Open your executor's workspace folder and look for **`My place.rbxlx`**. The `FilePath` option is a name without an extension; the saver adds the extension.

Open the file in Roblox Studio. Check a nearby building, a distant region, terrain, and a few saved scripts. A successful write confirms that an export was produced. It does not confirm that the client received every part of the map.

`Debug=true` also writes **`saveinstance-debug.txt`** in the workspace. Each run replaces that log, so keep a copy when comparing results.

## 3. Adjust the next save

| What you need | Next step |
|---|---|
| More of a streaming map | [Request streamed regions](./streaming) |
| Faster script decompilation or Oracle | [Set up decompilation](./decompilation) |
| A model instead of a place | Use the scoped example below |
| Missing terrain, scripts, or a failed export | [Troubleshoot the result](./troubleshooting) |

## Save a single model

Pass an actual instance, not its name. `Object` selects that instance and normally produces a model file.

```lua
saveinstance({
    Object = workspace:WaitForChild("YourModel"),
    FilePath = "My model",
    SafeMode = false,
})
```

Replace `YourModel` with the model you want. The output is `My model.rbxmx`.

For several selected instances, pass a list as the first argument:

```lua
saveinstance({workspace.BuildingA, workspace.BuildingB}, {
    FilePath = "Two buildings",
    SafeMode = false,
})
```

Replace those instance references with ones that exist in your place. The list form scopes the export to those instances rather than adding the usual game services.

## Save without decompiling

```lua
saveinstance({
    FilePath = "Map only",
    noscripts = true,
    SafeMode = false,
})
```

Script instances can still appear in the file, but the saver does not decompile their source. This is useful when you want to inspect geometry first.

For the rest of the settings, use the [options reference](./options).

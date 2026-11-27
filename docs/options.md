---
sidebar_position: 4
title: Options reference
---

# Options reference

Pass options as a table: `saveinstance({ Decompile = false })`. Names are case-insensitive. An unknown name prints a warning and is ignored.

You can also pass instances directly:

```lua
saveinstance(workspace.Castle)                         -- one model -> .rbxmx
saveinstance({ workspace.A, workspace.B })             -- several models
saveinstance(workspace.Castle, { FilePath = "Castle" }) -- instance + options
```

## What to save

| Option | Default | What it does |
|---|---|---|
| `Mode` | `"optimized"` | `"optimized"` saves the services a place needs. `"full"` saves every saveable service. `"scripts"` keeps only branches that contain scripts (`"script"` is an alias). |
| `Object` | `false` | An instance or list of instances to save as a model (`.rbxmx`). A service is saved as a folder. `Object = game` is the same as `Mode = "full"`. |
| `IsModel` | automatic | `true` when `Object` is set. Set `false` to save `Object` as a place. |
| `IgnoreList` | `{ "CoreGui", "CorePackages" }` | Leave out instances and everything under them. Entries: an instance, a class name, or `ClassName = { "Name", ... }`. `[instance] = false` keeps the instance but drops its children. |
| `IgnoreProperties` | `{}` | Property names never to write, e.g. `{ "Transparency" }`. |
| `IgnoreNotArchivable` | `true` | Also save instances with `Archivable = false`. Set `false` to skip them. |
| `RemovePlayerCharacters` | `true` | Leave player characters out of Workspace. |
| `NilInstances` | `false` | Save instances parented to nil (needs `getnilinstances`). |
| `IsolateLocalPlayer` | `false` | Save your Player's contents (PlayerGui, Backpack, ...) as folders. |
| `IsolateLocalPlayerCharacter` | `false` | Save your character. |
| `IsolatePlayers` | `false` | Save every Player as folders. |
| `IsolateStarterPlayer` | `false` | Also save a copy of StarterPlayer's contents as folders. |
| `ExtraInstances` | `{}` | More instances to include. |
| `SaveNotCreatable` | `false` | Save instances of classes Studio cannot create (Player, PlayerGui, ...) as folders instead of leaving them out. |

Extras from `NilInstances`, the `Isolate*` options and `ExtraInstances` go into `ServerStorage.SaveInstance420`, where they neither run nor render in Studio.

## Scripts

| Option | Default | What it does |
|---|---|---|
| `Decompile` | `true` | Decompile LocalScripts and ModuleScripts. `false` keeps the script instances with a note. Legacy: `noscripts`. |
| `DecompileTimeout` | automatic | Seconds per script: 30 for HTTP hooks such as Oracle, 10 for native decompilers. Failed scripts get one more try with three times as long. `0` = no limit. Legacy: `timeout`. |
| `DecompileConcurrency` | `16` | Requests in flight at once. Halves by itself when the provider says it is rate limited. |
| `DecompileIgnore` | `{ "TextChatService" }` | Save these scripts (and scripts under these instances) without decompiling them. Same entry format as `IgnoreList`. |
| `IgnoreDefaultPlayerScripts` | `true` | Leave out the engine's copies of `PlayerModule`, `RbxCharacterSounds`, `ChatScript` and `BubbleChat`, so Studio uses its working defaults. |
| `ScriptCache` | `true` | Reuse decompiled sources for the rest of the session (same bytecode = same source). Legacy: `scriptcache`. |
| `DecompileJobless` | `false` | Only use cached sources; decompile nothing new. |
| `SaveBytecode` | `false` | Append each script's bytecode (base64) to its source. |
| `DecompilerFallback` | `true` | When the executor has no `decompile()`, send bytecode to the lua.expert API instead. |
| `DecompilerApiUrl` | lua.expert | Endpoint for the fallback. |
| `DecompilerApiGap` | `0.12` | Seconds between fallback requests. |
| `DecompilerName` | automatic | Label written into each source header. Detected automatically for Oracle, lua.expert, Konstant, Medal and native decompilers. |

## Properties

| Option | Default | What it does |
|---|---|---|
| `IgnoreDefaultProperties` | `true` | Skip properties equal to the class default. Makes files much smaller. |
| `IgnoreSpecialProperties` | `false` | Never call `gethiddenproperty`. Use only if it crashes your executor: union data and some hidden properties will be missing. |
| `UseUGCValidationService` | `true` | Use `UGCValidationService` as a last-resort hidden-property reader. |
| `TreatUnionsAsParts` | `false` | Save unions as Parts. |
| `IgnoreSharedStrings` | `false` | Leave out SharedString properties (union meshes, tags). Only for executors that crash on them. |

## Streaming

See [Load streamed regions](./streaming).

| Option | Default | What it does |
|---|---|---|
| `SetStreaming` | `false` | Request the map around you before saving. Alias: `Streaming`. |
| `StreamingAreaSize` | `10000` | Side of the square to sweep, in studs. |
| `StreamingRadius` | `512` | Grid spacing and settle radius, in studs. |
| `StreamingCenter` | character | `Vector3` center of the sweep. |
| `StreamingSlices` | `2` | Vertical layers per grid point. |
| `StreamingPasses` | `1` | Repeat the sweep (1 to 3). |
| `StreamingPoints` | `false` | Your own list of `Vector3` points instead of a grid. |
| `StreamingConcurrency` | `4` | Requests in flight (max 8). |
| `StreamingTimeout` | `20` | Seconds per request. |
| `StreamingChunkWait` | `6` | Seconds to wait for a region's parts to stop changing. |
| `StreamingSettleTime` | `5` | Pause after the sweep for late arrivals. |
| `StreamingMaxTime` | automatic | Overall limit in seconds (max 3600). |

## Output and behavior

| Option | Default | What it does |
|---|---|---|
| `FilePath` | automatic | File name without extension. Default: `<place name> - <place id> - <UTC time>`. Legacy: `FileName`. |
| `Callback` | `false` | A function that receives the file in chunks instead of writing it. |
| `ShowStatus` | `true` | Show the progress panel. |
| `ReadMe` | `true` | Add a README ModuleScript to `ServerStorage.SaveInstance420`. |
| `Debug` | `false` | Write a log to `SaveInstance420/debug <time>.log`. |
| `NeutralizeLighting` | `false` | Reset the live Lighting to clear midday before saving, so the file does not open dark or foggy. |
| `SafeMode` | `false` | Disconnect from the server before writing the file and turn off 3D rendering while it runs. Streaming is skipped in SafeMode, since it needs the connection. |
| `AntiIdle` | `true` | Stop the 20-minute idle kick during long saves. |
| `ShutdownWhenDone` | `false` | Close the game when the save finishes. |
| `YieldBudget` | `8` | Milliseconds of work per frame. Raise for speed, lower if the game stutters. |

## Result

`saveinstance()` returns a table:

```lua
{
    ok = true,
    path = "Blox Fruits - 2753915549 - 2026-11-23 19.25.00.rbxlx",
    bytes = 186310284,
    instances = 167018,
    scripts = { decompiled = 5005, cached = 907, failed = 5, server = 74, unavailable = 14, total = 6005 },
    decompiler = "Oracle",
    decompilerStopped = nil, -- or the provider's message when it stopped answering (expired key, quota)
    elapsed = 286.8,
    warnings = {},
}
```

On failure: `{ ok = false, error = "...", trace = "..." }`. While a save runs, `getgenv().SaveInstance420Status` holds the current `phase`, `done`, `total`, `bytes` and `elapsed`.

## Run statistics

Run statistics for robloxscripts.com are not a `saveinstance()` option: they start when the script loads. Turn them off with `getgenv().RSOPS_OFF = true` before loading, or with `rsops/optout.txt` in your executor's workspace. See [Run statistics and privacy](./privacy).

## Retired options

`DecompilePrepass`, `PrepassConcurrency`, `PrepassMaxTime`, `PrepassRateGap`, `PrepassApiUrl`, `PrepassMaxScripts`, `SaveCacheInterval`, `AlternativeWritefile`, `SharedStringOverwrite`, `NilInstancesFixes`, `NotCreatableFixes`, `Anonymous`, `StreamingPreview`, `StreamingRequireComplete`, `StreamingCancel`, `StreamingValidate` and `ExportObj` are not part of 2.0. Retired names are ignored; the `Prepass*` ones are covered by the options under [Scripts](#scripts).

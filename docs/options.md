---
sidebar_position: 4
title: Options reference
---

# Options reference

Pass these settings to `saveinstance({ ... })`. Names are case-insensitive. The tables below cover the main controls; the [generated API reference](../api/SynSaveInstance) lists the remaining fields and aliases.

Defaults here follow the current script. Some compatibility defaults depend on your executor.

## Output and scope

| Option | Default | Behavior |
|---|---|---|
| `FilePath` | Automatic | Output name without an extension. |
| `mode` | `"optimized"` | Select game roots using `"optimized"`, `"full"`, or `"scripts"`. Scripts mode still includes surrounding hierarchy. |
| `Object` | `false` | Export a particular instance. Normally produces `.rbxmx`. |
| `IsModel` | `false` | Model output flag; automatically enabled when `Object` is supplied unless explicitly overridden. |
| `ExtraInstances` | `{}` | Add instances to the selected roots. For only selected instances, use the [list form](./intro#save-a-single-model). |
| `IgnoreList` | CoreGui, CorePackages | Skip listed instances or classes. |
| `IgnoreProperties` | `{}` | Omit named properties. |
| `IgnoreDefaultProperties` | `true` | Omit properties equal to their class defaults. |
| `IgnoreNotArchivable` | `true` | Ignore the `Archivable` flag and include non-archivable instances. Set false to respect it. |
| `NilInstances` | `false` | Include supported instances parented to nil. |
| `ReadMe` | `true` | Include the saver's readme content in the output. |
| `Callback` | `false` | Receive serialized data in a callback. The current writer can still create an initial file header. |

## Decompiler options

See [Decompile scripts](./decompilation) for executor-provided decompilers, lua.expert, and optional Oracle setup.

| Option | Default | Behavior |
|---|---|---|
| `noscripts` | `false` | Disable source decompilation; retain script instances. |
| `DecompilerName` | Automatic | Display label for the installed hook. Does not select a provider. |
| `DecompilePrepass` | `false` | Decompile eligible export scripts before serialization. |
| `PrepassConcurrency` | `4` | Concurrent provider calls; rounded down, maximum eight. |
| `PrepassMaxTime` | `300` | Overall worker deadline in seconds. |
| `timeout` | `10` | Per-script deadline in seconds. Alias: `DecompileTimeout`. |
| `PrepassMaxScripts` | `6000` | Above this unique uncached-job count, skip the prepass and decompile on demand. |
| `PrepassRateGap` | `0.12` | Minimum spacing in seconds for built-in API fallback requests. Does not affect custom hooks. |
| `PrepassApiUrl` | `https://api.lua.expert/decompile` | Built-in fallback endpoint. |
| `scriptcache` | `true` | Reuse decompiled source where bytecode and hash APIs are available. |
| `DecompileJobless` | `false` | Use cached source only; do not start new provider calls. |
| `DecompileIgnore` | TextChatService | Skip source for specified instances or classes. |
| `SaveBytecode` | `false` | Embed readable bytecode as Base64 in the source output. |

## Streaming options

The [streaming guide](./streaming) explains how to choose an area and check the result.

| Option | Default | Behavior |
|---|---|---|
| `SetStreaming` | `false` | Request regions before exporting. Alias: `Streaming`. |
| `StreamingAreaSize` | `10000` | Width of the request square in studs. |
| `StreamingRadius` | `512` | Request-grid spacing in studs. |
| `StreamingCenter` | `false` | Character position, or a supplied `Vector3`. |
| `StreamingPoints` | `false` | Explicit `Vector3` array instead of the generated grid. |
| `StreamingSlices` | `2` | Vertical layers. |
| `StreamingPasses` | `1` | Sweep repetitions. |
| `StreamingConcurrency` | `4` | Awaited requests in flight; maximum eight. |
| `StreamingTimeout` | `20` | Per-request deadline in seconds. |
| `StreamingChunkWait` | `6` | Post-request observation time in seconds. |
| `StreamingSettleTime` | `5` | Time for background loads to settle after the sweep. |
| `StreamingMaxTime` | `false` | Automatic overall limit, or a number of seconds. |
| `StreamingRequireComplete` | `true` | Stop the export after a failed or incomplete sweep. |
| `StreamingCancel` | `false` | Callback; return true to cancel and stop the export. |
| `StreamingValidate` | `false` | Coverage callback; return true, or false and a reason. |

## Appearance and players

| Option | Default | Behavior |
|---|---|---|
| `NeutralizeLighting` | `false` | Reset lighting and effects for a brighter saved scene. |
| `ExportObj` | `false` | Attempt a separate world-space mesh export to `.obj`; depends on mesh API access. |
| `TreatUnionsAsParts` | Executor-dependent | Save a plain Part representation where union geometry cannot be read. |
| `RemovePlayerCharacters` | `true` | Exclude player characters. |
| `IsolateLocalPlayer` | `false` | Isolate the local player's contents in the export. |
| `IsolateLocalPlayerCharacter` | `false` | Isolate the local character. |
| `IsolateStarterPlayer` | `false` | Isolate StarterPlayer contents. |
| `IsolatePlayers` | `false` | Isolate player data. |

## Status and compatibility

| Option | Default | Behavior |
|---|---|---|
| `ShowStatus` | `true` | Show the centered stage and progress panel. |
| `Debug` | `false` | Write `saveinstance-debug.txt` to the executor workspace. |
| `SafeMode` | `false` | Kick the player and change client state before saving. |
| `ShutdownWhenDone` | `false` | Shut down the client after a successful save. |
| `AntiIdle` | `true` | Enable the saver's anti-idle handling. |
| `IgnoreSpecialProperties` | Executor-dependent | Skip hidden-property reads, reducing the fidelity of some geometry. |
| `IgnoreSharedStrings` | Usually true | SharedString compatibility control; selected geometry handling is special-cased. |
| `UseUGCValidationService` | `true` | Allow the UGC validation fallback for property reads. |
| `AlternativeWritefile` | Usually true | Use the alternate writer; executor compatibility can change the default. |
| `IgnoreDefaultPlayerScripts` | Usually true | Skip default player scripts; differs on Wave. |
| `SaveCacheInterval` | `56320` | Buffered-write threshold in bytes. |

Change compatibility settings only when they address a specific failing path. Start with the [troubleshooting guide](./troubleshooting) rather than toggling several at once.

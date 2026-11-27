---
sidebar_position: 7
title: Develop SaveInstance
---

# Develop SaveInstance

`saveinstance.luau` at the repository root is generated. Edit the modules in `src/` and rebuild.

## Layout

| File | Role |
|---|---|
| `src/main.luau` | Entry point: phases, status, result table. |
| `src/options.luau` | Defaults, legacy aliases, call forms. |
| `src/env.luau` | Executor function lookup, base64/hash/SharedString keys (EncodingService first). |
| `src/schema.luau` | Saved properties per class: live ReflectionService merged with the snapshot, read strategies, defaults. |
| `src/schema_snapshot.luau` | Generated from the Full API dump. Do not edit. |
| `src/quirks.luau` | Exceptions the metadata gets wrong: blocked members, scriptable twins, rebuilt values, unsaveable classes. |
| `src/attributes.luau` | `AttributesSerialize` binary format. |
| `src/encode.luau` | XML encoders per value type. |
| `src/collect.luau` | Roots, ignore rules, extras, script list. |
| `src/scripts.luau` | Decompiler selection, worker pool, cache. |
| `src/serialize.luau` | Writes the document. |
| `src/writer.luau` | Chunked file output. |
| `src/streaming.luau` | Streaming sweep. |
| `src/ui.luau` | Status panel. |
| `src/telemetry.luau` | Run statistics: load success, feature and error counts for robloxscripts.com. |
| `src/prelude/telemetry.luau` | Not a module: the Script Ops line, pasted first in the bundle under its disclosure comment. |

Modules use `require("name")`; `tools/bundle.mjs` wraps each one in a function and resolves those calls inside the single output file. Files in `src/prelude/` are copied verbatim to the top of the bundle instead, before any module runs. The bundle passes the `ops` handle they define to `main`, and reports a failed load as `ready(false, "load_error")`. Delete the prelude to build without run statistics.

## Build

```bash
node tools/bundle.mjs
```

Bump `version.json` for releases; the bundle header and the status panel show it.

Run the collection regression checks locally with `lune run tools/test-collect.luau`.

If Xeno closes Roblox before the status panel appears, copy the rebuilt bundle to
`ssi-dev/saveinstance.luau` in its workspace and run `examples/diagnose-xeno.luau`.
The last line in `ssi-dev/startup.log` distinguishes compilation, initialization,
and the start of the save. A native crash cannot be caught by Lua's `pcall`.
With `Debug = true`, `SaveInstance420/last-operation.log` is overwritten before
nil-instance enumeration and hidden-property native calls, so it survives a
process crash. This adds synchronous disk writes; turn debug off after diagnosis.

## Update the property snapshot

After a Roblox update:

```bash
node tools/gen-schema.mjs
node tools/bundle.mjs
```

The generator reads Roblox-Client-Tracker's `Full-API-Dump.json`. Never switch it to `API-Dump.json` or `Mini-API-Dump.json`: those drop hidden members such as `Color3uint8` and `size`, and every part loses its color and size.

## Test against a live game

With the ExecutorMCP bridge running and its connector injected in a game:

```bash
node tools/live.mjs check                                   # build, deploy, compile in-game
node tools/live.mjs save "{ Decompile = false }"            # run a save and validate the file
node tools/live.mjs save "{ Object = workspace:FindFirstChildWhichIsA('Model') }"
node tools/live.mjs eval "return #game:GetDescendants()"
```

`SSI_WORKSPACE` overrides the executor workspace folder (Volt's is detected automatically) and `SSI_BRIDGE` the bridge address. Development saves are kept out of the run statistics (the script sets `RSOPS_OFF` only while the bundle loads); set `SSI_OPS=1` to include them.

`python tools/validate.py <file>` checks a saved file: unique referents, resolving Refs and SharedString keys, no duplicate properties, valid base64, plus a census of classes and value types.

## Rules learned the hard way

- Never `task.cancel` a thread that may be inside a native decompiler: Volt crashes. Abandon it.
- Never wrap an executor's `request` in `task.spawn`: some executors' `request` breaks there.
- Every loop over a whole game must call `Util.step()`, or big games freeze.
- Never write `UniqueId` or `HistoryId`: duplicates corrupt places.

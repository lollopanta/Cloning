---
sidebar_position: 3
title: Decompile scripts
---

# Decompile scripts

The client never receives Roblox source code, only compiled bytecode for the scripts it runs. SaveInstance turns that bytecode back into readable Luau with a decompiler and writes it into each script's `Source`.

## Which decompiler runs

Whatever `decompile()` is installed when the save starts is what runs:

1. **A loader's hook**, such as Oracle from your autoexec folder. Loaders replace `getgenv().decompile` with a function that sends the bytecode to their service.
2. **Your executor's native `decompile()`**, when no loader replaced it.
3. **The lua.expert API**, when there is no `decompile()` at all and the executor has `request` and `getscriptbytecode`. Turn this off with `DecompilerFallback = false`.
4. Otherwise scripts are saved with a note saying no decompiler was available.

SaveInstance works out which one it is and writes that name into the console, the status panel and the first line of every saved source:

```lua
-- SaveInstance 420 Edition: decompiled with Oracle
```

| Label | How it is recognised |
|---|---|
| `Oracle`, `lua.expert`, `Konstant`, `Medal` | A hook whose code contains that service's address. |
| `Volt decompile()` (your executor's name) | The executor's own native function. |
| `decompile() hook` | Any other hook. Name it with the registration below. |

To name a provider yourself, register it after its loader runs (the 1.x convention still works), or pass `DecompilerName` for one save:

```lua
getgenv().__SaveInstanceDecompiler = { Name = "My provider", Function = getgenv().decompile }
```

## Oracle

[Oracle](https://discord.gg/aqawE9RvVq) is a paid decompiler service. With its loader in your autoexec folder, every save decompiles through Oracle, and each unique script is one Oracle request against your plan. Scripts that share bytecode and scripts already decompiled this session are not requested again.

Oracle's loader returns its error messages as if they were source code. SaveInstance checks every answer:

| Oracle says | What SaveInstance does |
|---|---|
| Key has expired, key not redeemed, quota used up | Stops sending requests immediately and saves the remaining scripts with a note. The console shows Oracle's message. |
| Too many requests | Halves the number of requests in flight, waits (2 s, doubling up to 30 s), and retries the script. |
| `-- Decompilation failed!` and other error stubs | Marks that script as failed and tries it once more at the end. |

Error text is never saved as a script's source and never cached.

## What can be decompiled

| Script | Result |
|---|---|
| LocalScript, ModuleScript | Decompiled. |
| Script with `RunContext = Client` | Decompiled. |
| Server Script | A note. Server code never reaches the client. |
| Scripts under `DecompileIgnore` | A note; the instance is still saved. |
| Engine default player scripts | Left out (`IgnoreDefaultPlayerScripts`), so Studio uses its own working copies. |

## Speed

Decompiling happens before the file is written, in a pool:

- Scripts with identical bytecode are decompiled once (big games reuse hundreds of copies).
- Up to `DecompileConcurrency` requests are in flight at once (default 16). HTTP decompilers such as Oracle spend most of their time waiting on the network, so this is about 8 times faster than one at a time: 43 scripts in 1.3 s, and Blox Fruits' 5,000 unique scripts in about 4.5 minutes. A native decompiler runs one script at a time between frames.
- Each script has `DecompileTimeout` seconds: 30 for HTTP hooks, 10 for native decompilers. Scripts that fail or time out get one more try on their own with three times as long.
- Results are cached for the rest of the session (`ScriptCache`), so saving again is fast and costs no new Oracle requests.

The lua.expert fallback runs one request at a time, `DecompilerApiGap` seconds apart (default 0.12), because the API rejects bursts.

A thread that overruns its deadline is abandoned, not cancelled: cancelling a thread inside a native decompiler crashes Volt.

## When decompiling fails

The source says why, for example `decompile failed: timed out after 30s` or `decompiler returned nothing`. Some scripts (Actor scripts, unusual bytecode) consistently return nothing from a given decompiler; that is the decompiler's limit, not the save's.

- Decompiled code is a reconstruction. Names of locals are lost and some constructs need manual fixes.
- `SaveBytecode = true` appends the bytecode (base64) to each source so you can decompile it again later with another tool.
- Map only: `Decompile = false` skips the whole step.

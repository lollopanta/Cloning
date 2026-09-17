---
sidebar_position: 3
title: Decompile scripts
---

# Decompile scripts

SaveInstance uses the `decompile()` function installed in your executor environment. That may be the executor's own implementation or a hook installed by a loader such as Oracle.

## Which provider runs?

| Available in your client | What SaveInstance uses |
|---|---|
| An installed `decompile()` function | That function, including a configured Oracle hook |
| No hook, but bytecode, Base64, and HTTP APIs exist | The built-in lua.expert fallback |
| Neither path is available | Source cannot be decompiled through those paths |

A failing installed hook does not automatically switch to lua.expert. Setting a provider name only changes the label; it does not install or select a decompiler.

## Use Oracle

Run your configured Oracle loader before SaveInstance. Your subscription and credentials stay in that loader; they are not part of this repository.

Immediately after the loader installs its function, register the name:

```lua
getgenv().__SaveInstanceDecompiler = {
    Name = "Oracle",
    Function = getgenv().decompile,
}
```

The registration applies only while that exact function is installed. If a later loader replaces it, register the replacement again with its correct name.

You can also pass `DecompilerName = "Oracle"` for a single save. This is a display override, so use it only when you know that the installed hook is Oracle.

## Check the saved source

The status panel and console identify the selected provider. Each saved script also carries a line beneath its banner:

```lua
-- Saved by USSI modded by Robloxscripts.com (Join the Discord) discord.robloxscripts.com
-- Decompiler used: Oracle
```

| Label | Meaning |
|---|---|
| `Oracle` | Output obtained through the hook registered as Oracle |
| `Oracle (cached)` | A cache hit whose recorded provider was Oracle |
| `Executor decompile() (Volt)` | An installed hook without a recognized provider registration |
| `Unknown (legacy cache)` | Cached text that predates provider tracking |
| `None (ignored)` or `None (disabled)` | Decompilation was intentionally skipped |
| `None (server-only source unavailable)` | The client cannot provide that server source |
| `None (prepass stopped)` | The prepass aborted and no cached source was available |

Cached output keeps its original provider label. Naming the current hook Oracle does not relabel an old cache entry.

## Run a faster prepass

```lua
saveinstance({
    DecompilePrepass = true,
    PrepassConcurrency = 4,
    PrepassMaxTime = 300,
    timeout = 10,
    SafeMode = false,
    Debug = true,
})
```

The prepass gathers eligible scripts from the export, deduplicates them, and fills the cache before writing source. It respects the export scope and ignore rules.

Four workers is the default. The count is rounded down and capped at eight. For Oracle, this overlaps requests while other requests wait; it is not CPU multithreading. Your provider's rate limits still apply.

A small Maple County test of 12 scripts took **1.97 seconds with one worker** and **0.86 seconds with four**. Outputs matched. That is a measured sample, not a whole-game performance guarantee.

## Read the progress panel

The centered panel shows completed jobs, total jobs, successful and failed results, cache hits, active workers, and an estimated time remaining. The estimate changes as jobs finish.

`timeout` is the per-job deadline. `PrepassMaxTime` is the overall worker deadline. If the pool aborts, completed cache entries remain usable, but the save does not start replacement on-demand calls for missing entries. This prevents a timed-out native call from silently increasing the number of active calls.

A provider that blocks the executor's scheduler cannot be forcibly interrupted by a Luau timer. Provider hooks should throw or return `nil` on failure; a hook that returns an error message as ordinary source text can make that error look like a successful result.

## Turn decompilation off

Use `noscripts = true` for an export without decompiled source. `DecompilePrepass = false` only disables the prepass; normal on-demand decompilation remains enabled.

Use `DecompileJobless = true` if you want cached source only, with no new decompiler calls. See the [decompiler options](./options#decompiler-options) for the full set of controls.

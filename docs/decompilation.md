---
sidebar_position: 3
title: Decompile scripts
---

# Decompile scripts

You do not need Oracle or another paid service to use SaveInstance. If your executor provides a `decompile()` function, SaveInstance uses it by default. Third-party decompilers are optional alternatives.

## Choose your setup

| Setup | Access | How it fits into SaveInstance |
|---|---|---|
| Executor-provided decompiler | Included with supported executors | The default when a `decompile()` function is installed. Volt and Potassium are examples of executors that provide one. |
| lua.expert | Free, third-party service | Available through the built-in HTTP fallback when no hook is installed, or through a supported provider integration. |
| Oracle | Paid, third-party service: $10/month | Optional for subscribers who install its loader before SaveInstance. Not included or required. |

Oracle pricing above is supplied by the project maintainer as of September 2026; confirm current terms with the provider. This guide does not assume that users have an Oracle subscription.

SaveInstance calls the interface an executor exposes; it does not need to know the underlying decompiler implementation. Executor-provided does not necessarily mean the implementation was developed from scratch. We do not infer a decompiler's codebase or lineage from the executor name.

## Which provider runs?

1. An installed `decompile()` function takes precedence. It may be the executor's built-in function or a replacement installed by a third-party loader.
2. With no installed hook, SaveInstance uses its lua.expert HTTP fallback if bytecode, Base64, and HTTP functions are available.
3. If neither path is available, those scripts cannot be decompiled through these paths.

A failing installed hook does not automatically switch providers. `DecompilerName` is only a label, and `PrepassApiUrl` only controls the fallback endpoint; neither overrides an installed hook.

## Use your executor's decompiler

Run SaveInstance in a session where no third-party loader has replaced `decompile()`. No provider subscription or registration is needed.

```lua
saveinstance({
    DecompilePrepass = true,
    PrepassConcurrency = 4,
    SafeMode = false,
})
```

This example works with the selected provider, not just a particular executor. The prepass is optional: without it, scripts are decompiled on demand while saving.

If an auto-execute loader replaces the built-in function, disabling that loader and starting a fresh session is a straightforward way to return to the executor's own implementation. Changing the display name does not restore a function that was replaced.

## Use lua.expert

lua.expert is a **free third-party decompiler**. Its remote API receives script bytecode and returns Luau source. It is separate from the native decompilers supplied by executors.

- [Web demo](https://lua.expert/demo): upload bytecode and inspect the result in your browser.
- [Provider helper script](https://lua.expert/script.lua): the integration link supplied by lua.expert.
- [API documentation](https://lua.expert/docs): request format and current service limits.

**Automatic fallback:** if there is no installed `decompile()` hook and the required APIs exist, no extra loader is needed. SaveInstance already uses `https://api.lua.expert/decompile`.

**Using it instead of an installed hook:** install lua.expert's supported `decompile()` integration before loading SaveInstance, then register that function as `lua.expert` using the example below. Do not assume that opening the demo or setting `DecompilerName` changes providers.

At our September 18, 2026 check, the helper-script URL returned the site's HTML page rather than Luau. The API docs still link to it. Confirm the current integration with lua.expert before trying to execute that URL; this guide deliberately does not provide an unchecked `loadstring` command for it. The web demo is a separate manual tool, not a SaveInstance hook.

## Use Oracle

Oracle is an **optional paid third-party decompiler**, listed at **$10 per month**. Get access and the current loader through the [Oracle Discord](https://discord.gg/aqawE9RvVq).

If you have access, run your configured Oracle loader before SaveInstance. Keep its credentials in the provider's loader, outside saved outputs and shared scripts. SaveInstance does not include an Oracle key or subscription.

After the loader installs its hook, register that exact function with `Name = "Oracle"`. The same registration mechanism works for any compatible third-party provider.

## Identify a custom provider

Run this **after** a provider has installed `getgenv().decompile`. Change the name to the provider you actually installed:

```lua
getgenv().__SaveInstanceDecompiler = {
    Name = "lua.expert", -- Or "Oracle", after installing Oracle
    Function = getgenv().decompile,
}
```

This records a name; it does not download or install a provider. Registration applies only while that exact function remains installed. Register again if a later loader replaces it.

For a single save, `DecompilerName = "Provider name"` is also available as a display override. Use it only when you know which implementation is active.

## Check the saved source

The status panel and console show the selected provider. Each saved source records the provider used for that result. For example, an unregistered hook in Volt is labelled:

```lua
-- Saved by USSI modded by Robloxscripts.com (Join the Discord) discord.robloxscripts.com
-- Decompiler used: Executor decompile() (Volt)
```

| Label | Meaning |
|---|---|
| `Executor decompile() (Volt)` | The selected unregistered hook in Volt; the executor name alone does not prove which implementation is behind it. Other executors show their own name. |
| `lua.expert` | The built-in lua.expert fallback, or a hook registered with that name |
| `Oracle` | A hook registered as Oracle; requires a separate provider setup |
| `lua.expert (cached)` / `Oracle (cached)` | Cached source with the recorded provider shown; the same suffix applies to executor-provided results |
| `Unknown (legacy cache)` | Cached text without recorded provider information |
| `None (ignored)` / `None (disabled)` | Decompilation was intentionally skipped |
| `None (server-only source unavailable)` | The client cannot provide that server source |
| `None (prepass stopped)` | The prepass aborted and no cached source was available |

A cache entry keeps its original provider label even if you switch providers later. To compare providers on fresh output, use `scriptcache=false` with the prepass off; otherwise a cache hit can reuse earlier results.

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

Four workers is the default. The count is rounded down and capped at eight. For remote providers such as lua.expert and Oracle, this can overlap requests while others wait. It does not turn a built-in decompiler into a multithreaded CPU decompiler. Speedup depends on the installed provider, and its rate limits still apply.

Using Oracle, a small Maple County test of 12 scripts took **1.97 seconds with one worker** and **0.86 seconds with four**. Outputs matched. That is a measured sample, not a whole-game performance guarantee.

## Read the progress panel

The centered panel shows completed jobs, total jobs, successful and failed results, cache hits, active workers, and an estimated time remaining. The estimate changes as jobs finish.

`timeout` is the per-job deadline. `PrepassMaxTime` is the overall worker deadline. If the pool aborts, completed cache entries remain usable, but the save does not start replacement on-demand calls for missing entries. This prevents a timed-out native call from silently increasing the number of active calls.

A provider that blocks the executor's scheduler cannot be forcibly interrupted by a Luau timer. Provider hooks should throw or return `nil` on failure; a hook that returns an error message as ordinary source text can make that error look like a successful result.

## Turn decompilation off

Use `noscripts = true` for an export without decompiled source. `DecompilePrepass = false` only disables the prepass; normal on-demand decompilation remains enabled.

Use `DecompileJobless = true` if you want cached source only, with no new decompiler calls. See the [decompiler options](./options#decompiler-options) for the full set of controls.

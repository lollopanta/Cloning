# SaveInstance 420 Edition

Export Roblox places and models from the state available to your client. Includes streaming requests, terrain serialization, decompiler identification, and a bounded decompile prepass.

## Start here

```lua
local saveinstance = loadstring(game:HttpGet(
    "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
))()

saveinstance({
    SafeMode = false,
    Debug = true,
})
```

The output goes to your executor's workspace. Open it in Studio and check recognizable geometry and scripts before relying on it. A finished export does not prove complete streaming coverage.

## Documentation

- [Make your first save](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/intro/)
- [Load streamed regions](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/streaming/)
- [Choose a decompiler](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/decompilation/)
- [Options reference](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/options/)
- [Troubleshoot an export](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/troubleshooting/)

## Decompiler behavior

The installed `decompile()` hook takes precedence, normally using your executor-provided decompiler unless a loader has replaced it. lua.expert is a free third-party alternative and the built-in fallback when no hook exists and the required APIs are available. Oracle is an optional paid third-party service ($10/month; [provider access](https://discord.gg/aqawE9RvVq)). No Oracle subscription is required to use SaveInstance. `DecompilePrepass=true` enables a four-worker prepass by default. Each saved source records the provider used, including cache provenance where known.

## Source and credits

Maintained by SirMeme at the [self-hosted repository](https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition). Built on [UniversalSynSaveInstance](https://luau.github.io/) by the luau project, with streaming and prepass ideas from [centerepic](https://github.com/centerepic). Built-in HTTP fallback provided by [lua.expert](https://lua.expert).

[Robloxscripts.com](https://robloxscripts.com) · [Community Discord](https://discord.robloxscripts.com)

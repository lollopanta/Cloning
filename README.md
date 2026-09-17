# SaveInstance 420 Edition

Export Roblox places and models from the state available to your client. Includes streaming requests, terrain serialization, decompiler identification, and a bounded decompile prepass.

## Start here

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

The output goes to your executor's workspace. Open it in Studio and check recognizable geometry and scripts before relying on it. A finished export does not prove complete streaming coverage.

## Documentation

- [Make your first save](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/intro/)
- [Load streamed regions](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/streaming/)
- [Decompile scripts and configure Oracle](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/decompilation/)
- [Options reference](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/options/)
- [Troubleshoot an export](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/troubleshooting/)

## Decompiler behavior

The installed `decompile()` hook takes precedence, including a configured Oracle loader. When no hook exists, the saver can use lua.expert if the required APIs are available. `DecompilePrepass=true` enables a four-worker prepass by default. Each saved source records the provider used, including cache provenance where known.

## Source and credits

Maintained by SirMeme at the [self-hosted repository](https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition). Built on [UniversalSynSaveInstance](https://luau.github.io/) by the luau project, with streaming and prepass ideas from [centerepic](https://github.com/centerepic). Built-in HTTP fallback provided by [lua.expert](https://lua.expert).

[Robloxscripts.com](https://robloxscripts.com) · [Community Discord](https://discord.robloxscripts.com)

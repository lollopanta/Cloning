# SaveInstance 420 Edition

Save Roblox places and models from what your client can see: map, UI, terrain, attributes, tags, and decompiled LocalScripts and ModuleScripts.

Version 2 is a complete rewrite. It downloads no helper code at runtime, reads the property list for the exact Roblox build you are on, and decompiles with a worker pool, so large games save in minutes instead of hours.

## Start here

```lua
local saveinstance = loadstring(game:HttpGet(
    "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
))()

saveinstance()
```

The file goes to your executor's workspace as `<place name> - <place id> - <UTC time>.rbxlx`. Open it in Studio and check a few landmarks and scripts before relying on it.

Common variations:

```lua
saveinstance({ Decompile = false })            -- map only, fastest
saveinstance({ SetStreaming = true })          -- StreamingEnabled games: load the map first
saveinstance(workspace.SomeModel)              -- one model, saved as .rbxmx
saveinstance({ NilInstances = true, Debug = true })
```

Options from older SaveInstance versions (`noscripts`, `timeout`, `mode`, `FileName`, ...) still work.

## Run statistics

**SaveInstance tracks execution data (run statistics) for [robloxscripts.com](https://robloxscripts.com/script-ops).** When it loads, it starts robloxscripts.com's Script Ops reporter, which sends:

- SaveInstance's version, Roblox's version, your executor and its version, the game's place id, universe id and place version, the server kind, device and OS type, Roblox's language and start-up time;
- a check-in every 5 minutes while the game runs, with re-runs and counts of the SaveInstance features you used (save type, decompiler kind, options switched on, whether the save worked) and of errors;
- how the session ended (left, kicked, disconnected) and Roblox's error code.

It never sends your Roblox user id, name or display name, the server's JobId, private server ids or hardware ids, and never anything from the place you save. Error and kick text is scrubbed of names and file paths, and kept only if the project collects it (currently off). The reporter runs on its own thread, so saving works even if robloxscripts.com is down.

**Turn it off** with `getgenv().RSOPS_OFF = true` before loading SaveInstance, or by creating `rsops/optout.txt` in your executor's workspace. Details: [Run statistics and privacy](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/privacy/).

## What's new in 2.0

- **Nothing breaks when a website goes away.** The old script downloaded a helper from a repository that no longer exists, which is why it failed with `attempt to call a nil value`. Saving in version 2 downloads nothing; the run-statistics reporter and the optional lua.expert fallback run separately and cannot stop a save.
- **Property list from the running client.** Roblox's `ReflectionService` describes every saved property of the exact build you are on. A snapshot generated from the full API dump fills in the members it hides (attributes, tags, union data, script source). The API dump the old version downloaded had stopped updating and was missing hundreds of newer properties.
- **Fast decompiling.** HTTP decompilers like Oracle mostly wait on the network, so 2.0 keeps 16 requests in flight, decompiles identical scripts once, and caches results for the session. On Blox Fruits: 5,900 scripts in about 4.5 minutes.
- **Knows which decompiler ran.** Oracle, lua.expert and native decompilers are recognised and named in every saved source. Error text from a provider (expired key, rate limit) is never saved as code: SaveInstance slows down on rate limits and stops on key or quota errors.
- **Low memory.** The file is streamed to disk in chunks and the game keeps rendering while it saves.
- **Correct modern formats.** `ContentId` and `Content` asset properties, `Font`, `SecurityCapabilities`, `OptionalCoordinateFrame`, `AcousticAbsorption`, and SharedString keys that match Roblox's.
- **Safer extras.** Nil instances, isolated players and the readme go into `ServerStorage.SaveInstance420`, where nothing runs or renders.

## Documentation

- [Make your first save](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/intro/)
- [Load streamed regions](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/streaming/)
- [Decompile scripts](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/decompilation/)
- [Options reference](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/options/)
- [Troubleshoot an export](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/troubleshooting/)
- [Run statistics and privacy](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/privacy/)
- [Develop SaveInstance](https://pages.sirmemegithub.com/SaveInstance420Edition/docs/development/)

## Source and credits

Maintained by SirMeme at the [self-hosted repository](https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition). `saveinstance.luau` is built from the modules in `src/`; see the development guide. Inspired by [UniversalSynSaveInstance](https://luau.github.io/) by the luau project, with streaming ideas from [centerepic](https://github.com/centerepic). Free decompiler fallback by [lua.expert](https://lua.expert). XML formats follow [rbx-dom](https://github.com/rojo-rbx/rbx-dom).

[Robloxscripts.com](https://robloxscripts.com) · [Community Discord](https://discord.robloxscripts.com)

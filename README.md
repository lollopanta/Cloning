# SaveInstance 420 Edition

The saveinstance that actually saves your game **the way it looks.**

Exports the instances available to your client, with streaming helpers, terrain serialization, and decompiler support.

## Why use this one

- 🎨 **Correct colors & sizes** — other savers drop these and everything loads grey and default-sized. This saves them right.
- 🖼️ **Decals, images & sounds save** — the stuff modern savers silently miss.
- 🧩 **Unions & terrain render properly** — not invisible, not grey boxes.
- 🗺️ **Streaming coverage tools** — request additional map regions before saving; coverage depends on what the server streams to the client.
- 📜 **Decompiles scripts even if your executor can't** — free built-in fallback, plus a fast parallel mode for script-heavy games.
- ☀️ **Opens bright** — optional one-liner so your save isn't dark and foggy.
- 🧱 **Recovers meshes** — pull private mesh geometry out to `.obj` (Blender-ready).
- ⚡ **Bounded decompiler concurrency** — defaults to four workers, with deadlines and progress reporting.
- 🔌 **Executor capability checks** — available features depend on the executor APIs.

## Usage

```lua
local Params = {
    RepoURL = "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/",
    SSI = "saveinstance",
}

local synsaveinstance = loadstring(game:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()

synsaveinstance({
    SetStreaming = false,       -- true = request additional streamed regions
    DecompilePrepass = false,   -- true = decompile eligible exported scripts
    NeutralizeLighting = false, -- true = save opens in bright daylight
    ExportObj = false,          -- true = also dump meshes to a .obj
})
```

That's it — one call, no extra scripts. The optional features shown above are off by default; normal script decompilation is enabled.

📖 **Full option list:** https://pages.sirmemegithub.com/SaveInstance420Edition/

## Faster script exports

Enable `DecompilePrepass = true` with `PrepassConcurrency = 4`. The saver uses the installed `decompile()` hook, including a configured Oracle loader; lua.expert is used when that hook is absent. Each exported source identifies its provider beneath the banner. The centered status panel shows progress and ETA. See the option list for provider registration and timeout behavior.

## Credits

Built on the original **[UniversalSynSaveInstance](https://luau.github.io/)** by the luau project — please support them.
Streaming & prepass ideas by [centerepic](https://github.com/centerepic). Decompiler by [lua.expert](https://lua.expert).

Modified by **Robloxscripts.com** — Discord: discord.robloxscripts.com

<!-- sirmeme-watermark -->

---
<sub>⭐ <b>Official source:</b> <a href="https://sirmemegithub.com/RealSlimShady2000/saveinstance420edition">sirmemegithub.com/RealSlimShady2000/saveinstance420edition</a> &nbsp;·&nbsp; built &amp; maintained by <b>SirMeme</b>. Got this somewhere else? Grab the latest, verified version at the link above.</sub>
<!-- /sirmeme-watermark -->

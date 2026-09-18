---
sidebar_position: 2
title: Load streamed regions
---

# Load streamed regions

A streaming-enabled place may only send your client the area near your character. Saving that client state can leave distant buildings or terrain incomplete.

`SetStreaming` requests more regions before serialization. Request completion is useful evidence, but it is not a promise that the whole map arrived or stayed loaded.

## Preview the area without saving

Use `StreamingPreview=true` to see the plan before requesting regions or writing a file. `PreviewOnly=true` is an alias.

```lua
local preview = saveinstance({
    StreamingPreview = true,
    StreamingAreaSize = 2048,
    StreamingRadius = 512,
    StreamingPreviewTransparency = 0.5,
})
```

The blue plane marks the planned area, grid lines show spacing, and yellow markers show request positions across the configured vertical layers. This is a plan, not evidence that those regions are loaded. `StreamingRadius` controls grid spacing; it is not a guaranteed engine loading radius.

The preview panel reports area, spacing, and request count. Choose **View from above** for a top-down camera view, **Restore camera** to return, or **Clear preview** to remove it. Your character does not move. Large plans show a sampled set of markers to limit visual overhead; the panel tells you how many are shown.

Change the values and run the preview again to replace it. A normal save automatically removes the preview helpers and restores a preview-controlled camera first. Preview mode itself does not request streaming, decompile scripts, or write files.

You can also remove the preview from code:

```lua
preview:Destroy()
-- Or, without keeping the returned handle:
saveinstance({StreamingPreview = "clear"})
```

## Save the area you previewed

When you are ready, use the same area and spacing with `SetStreaming=true` and leave out `StreamingPreview`. The sweep uses the same point planner as the preview. Both use your current character position by default; set the same `StreamingCenter` on both calls if you move between previewing and saving.

## Start with a known area

Run the loader from [Make your first save](./intro), then use:

```lua
saveinstance({
    FilePath = "Streaming test",
    SetStreaming = true,
    StreamingAreaSize = 2048,
    StreamingRadius = 512,
    noscripts = true,
    SafeMode = false,
    Debug = true,
})
```

This example requests a square around your starting position. It keeps script decompilation out of the first geometry check. After the export, compare recognizable buildings and terrain in Studio with the live game.

## What the sweep controls

| Setting | Default | Meaning |
|---|---|---|
| `StreamingAreaSize` | `10000` | Width of the requested square, in studs. Larger areas take more requests. |
| `StreamingRadius` | `512` | Grid spacing. This is **not** a radius passed to the engine. |
| `StreamingCenter` | `false` | Use your character's position; supply a `Vector3` to choose another center. |
| `StreamingSlices` | `2` | Number of vertical request layers. |
| `StreamingPasses` | `1` | Number of passes through the request points. |
| `StreamingConcurrency` | `4` | Requests in flight; bounded at eight. |
| `StreamingTimeout` | `20` | Seconds allowed for an individual request. |
| `StreamingChunkWait` | `6` | Observation time after a request. Stable counts alone do not prove completeness. |
| `StreamingSettleTime` | `5` | Time allowed for background loads to settle after the sweep. |
| `StreamingMaxTime` | `false` | Automatic overall deadline; set seconds to choose a fixed deadline. |
| `StreamingRequireComplete` | `true` | Abort the export when the sweep fails or is incomplete. |

Start small, then widen the area. Increasing concurrency does not make the server send content it has not made available to your client.

## Request specific locations

Use `StreamingPoints` when you know which regions are missing. Supply an array of `Vector3` positions; it replaces the generated grid.

```lua
saveinstance({
    SetStreaming = true,
    StreamingPoints = {
        Vector3.new(0, 50, 0),
        Vector3.new(512, 50, 0),
    },
    noscripts = true,
    Debug = true,
})
```

The positions above are placeholders. Use coordinates from your place. The built-in request sweep does not perform the separate character-teleport tour used in some diagnostic tests.

## Cancel or validate a sweep

`StreamingCancel` accepts a callback that returns `true` to cancel the sweep and stop the export. `StreamingValidate` accepts a final coverage check that returns `true`, or `false` and a reason.

```lua
local stop = false

saveinstance({
    SetStreaming = true,
    StreamingCancel = function()
        return stop
    end,
})
```

Connect `stop` to your own control if you use this pattern. A coverage check should inspect landmarks or geometry you expect to exist, not just count successful requests.

## When parts are still missing

Check the same landmarks on each attempt. Note which buildings, surfaces, or regions changed. File size and a finished progress bar are poor substitutes for that comparison.

If objects are present but textures or sounds fail to load, that may be an asset-access issue rather than a streaming issue. See [missing content](./troubleshooting#missing-content).

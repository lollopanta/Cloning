---
sidebar_position: 2
title: Load streamed regions
---

# Load streamed regions

In a game with `StreamingEnabled`, the server only sends your client the area around your character. A save of that client state misses everything farther away.

`SetStreaming = true` asks the server for the rest of the map before saving:

```lua
saveinstance({
    SetStreaming = true,
    StreamingAreaSize = 4000, -- sweep a 4000 x 4000 stud square around you
})
```

Your character does not move. If the game does not use streaming, the option does nothing.

## How the sweep works

1. A grid of points covers `StreamingAreaSize` around `StreamingCenter` (your character by default), `StreamingRadius` studs apart, at `StreamingSlices` heights.
2. Up to `StreamingConcurrency` points are requested at once with `Player:RequestStreamAroundAsync`. A request that hangs past `StreamingTimeout` is abandoned (on empty or ocean regions it can hang longer than its own timeout).
3. After each request, the region's anchored part count is watched until it stops changing, for up to `StreamingChunkWait` seconds.
4. When the grid is done, or `StreamingMaxTime` runs out, the save waits `StreamingSettleTime` seconds for late arrivals.

While the sweep and the save run, `Workspace.StreamOutBehavior` is set to `LowMemory` so the client keeps what it loaded; it is restored afterwards. Terrain is read when the file is written, after the sweep.

The console reports the outcome:

```text
[SaveInstance] streaming: 121/121 regions requested, 0 failed, 3 still loading, 2m 14s
```

## Choosing the area

| Map | Try |
|---|---|
| Small arena | `StreamingAreaSize = 1500` |
| City or island | `StreamingAreaSize = 4000` |
| Huge open world | Save in parts: several runs with different `StreamingCenter` values, or `StreamingPoints = { ... }` |

The grid is limited to 10,000 requests. A bigger `StreamingRadius` means fewer requests and less detail per request. Making the engine's own streaming radius huge does not help: it loads more at once and can run the client out of memory.

## What streaming cannot do

- It cannot load what the server refuses to send.
- The game can still remove parts on its own (cleanup, round changes).
- A region that "settled" is an observation, not proof that every part arrived. Check distant landmarks in Studio.

`StreamingPreview` (the area visualizer from 1.x) has not been carried over to 2.0 yet.

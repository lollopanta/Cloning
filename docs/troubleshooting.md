---
sidebar_position: 5
title: Troubleshoot an export
---

# Troubleshoot an export

Run the failing save again with `Debug = true` and keep `SaveInstance420/debug <time>.log` from your executor's workspace. Change one option at a time.

## The save fails or stops

| Symptom | Try |
|---|---|
| `[SaveInstance] save failed: ...` in the console | The message names the stage. Send it with the debug log. |
| It sits on "Decompiling scripts" | A remote `decompile()` hook may be rate-limiting: lower `DecompileConcurrency` (for example 4). Or skip it: `Decompile = false`. |
| The game stutters a lot while saving | Lower `YieldBudget` (for example 4). |
| The executor crashes | Try `IgnoreSpecialProperties = true` (no `gethiddenproperty` calls), then `IgnoreSharedStrings = true`. Each removes some data from the save. |
| "A save is already running" | Wait for the first one, or rejoin if it crashed mid-save. |

A save that failed deletes its partial file.

## Missing or wrong content

| What you see | Why, and what to do |
|---|---|
| Distant areas missing | The game streams. Use `SetStreaming = true`, see [streaming](./streaming). |
| Unions are plain boxes | Unions made with newer Studio keep their shape in `SolidMeshHolder`, which no executor can read. Nothing on the client can recover those. `TreatUnionsAsParts = true` turns them into Parts instead. |
| MeshParts are grey boxes | The mesh asset is private to the game's owner, so Studio cannot download it. |
| Textures or sounds missing | Same cause: asset permissions. The save keeps the asset ids. |
| Server scripts only contain a note | Server code never reaches the client. |
| A script says `decompile failed` | See [Decompile scripts](./decompilation#when-decompiling-fails). |
| The place opens dark or foggy | That is the game's real lighting. `NeutralizeLighting = true` resets it before saving. |
| My character will not spawn in Studio | Move the scripts out of StarterPlayer, then run `game:GetService("Players").CharacterAutoLoads = true` in the command bar. |
| The camera will not move | `workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed`, or delete the Camera. |

## Check a file without Studio

The repository has a validator that checks structure (unique referents, references, SharedStrings, base64) and prints what is in the file:

```bash
python tools/validate.py "path/to/save.rbxlx"
```

## Report a problem

Include the place, your executor, the options you used, what went wrong, and the debug log. Report issues on the [self-hosted repository](https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/issues).

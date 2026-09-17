---
sidebar_position: 5
title: Troubleshoot an export
---

# Troubleshoot an export

Keep the first failing file and its debug log. Change one setting for the next attempt so you can tell what helped.

## The client closes or freezes

Run a smaller scoped export with `Debug=true`. Save its `saveinstance-debug.txt` before another run overwrites it. Record the executor, place, options, and the last visible stage.

Try `noscripts=true` to isolate geometry and serialization from decompilation. If a map-only save works, investigate the installed provider and its timeout behavior before increasing worker counts.

`SafeMode` is not a neutral crash fix: it kicks the player and changes the live client state. Leave it off when testing the normal connected save path.

## Missing content

| What you see | What to check next |
|---|---|
| Distant buildings absent or half-built | Compare live landmarks; try a scoped streaming request. See [streaming](./streaming). |
| Roads or trees above empty terrain | Check terrain in the same locations before and after export. Do not infer completeness from file size. |
| Objects exist, but textures or sounds fail | Read Studio's output for asset-access errors. Saved references do not grant access to restricted assets. |
| Server scripts have no source | Server-only source is not available through the client's normal replicated state. |
| Unions look like plain boxes | Check executor hidden-property support and `TreatUnionsAsParts`. |
| The saved scene is too dark | Use `NeutralizeLighting=true` only if you want the export's lighting reset. |

## The wrong decompiler name appears

Check which loader ran last. SaveInstance uses the currently installed hook, not the brand of your executor. Register the hook's name after installing it; see [Oracle setup](./decompilation#use-oracle).

An `Unknown (legacy cache)` label is deliberate. The saver cannot recover the provider for cached text that never recorded it.

## Decompilation stops partway through

Check the source labels and log. A deadline stops the pool from launching further work, and uncached scripts are marked as stopped. Lower `PrepassConcurrency` if the provider is rejecting calls. Increase a deadline only when the provider is still making useful progress.

`PrepassRateGap` controls the built-in HTTP fallback. It does not throttle a custom Oracle hook. A paid-provider error body is not necessarily valid source; check the result if the loader returns error text without throwing.

## The file will not open in Studio

Confirm that the save reported success and that the file has finished writing. Keep the file and debug log. A partial file left by a failed run is not a valid completed export.

Test a small model next. If that opens, widen the export until the failure becomes reproducible. Avoid repeatedly exporting a huge place before you have a smaller failing case.

## Share a useful report

Include:

- Place name or ID, executor name, and saver revision.
- The exact options you used.
- Whether the client closed, froze, or reported a Lua error.
- The last stage and relevant lines from `saveinstance-debug.txt`.
- A screenshot or named landmark for missing geometry.

Remove provider keys and other credentials before posting logs. Report issues on the [self-hosted repository](https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/issues).

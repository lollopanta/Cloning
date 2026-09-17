# Save reliability and bounded decompilation

- Identify the selected decompiler in the status panel, debug output, and each saved source. Preserve provider provenance on cache hits; distinguish unknown legacy cache entries.
- Prefer the exact script-bytecode API on Volt; fuzzy discovery previously selected a function-only bytecode API and bypassed caching.
- Prepass defaults to four concurrent calls, caps at eight, enforces worker and overall deadlines, and prevents late callbacks or replacement calls after an abort.
- Gather only eligible export roots and respect ignore/archive rules. Deduplicate jobs by hash without retaining every bytecode string.
- Correct the two-argument instance-list form so default game services are not added.
- Center the readable status panel, with backend, progress, success/failure/cache counts, active workers, and ETA.
- Remove the unused slow Base64 encoder, avoid logging upstream HTTP response bodies, and point documentation configuration at the self-hosted site.

## Validation

The shipped pool and gather regression tests pass (15 pool scenarios and 11 gather fixtures). Source compilation, decompiler provenance tests, terrain serialization fixtures, and streaming regression checks pass.

Live Maple County on Volt with Oracle: a 12-script benchmark took 1.97 s with one worker and 0.86 s with four, with identical outputs and no reported errors. A scoped integrated export contained exactly 12 requested instances: one ignored script and 11 cached sources from ten unique provider calls; it completed in 1.13 s with SafeMode=false. A controlled timeout made one call, cached nothing, and did not start replacement work. The centered panel measured 680 by 150 pixels and its status text fit.

These scoped tests do not establish complete map coverage or a whole-game speedup. Hook providers must throw on errors or return nil rather than returning error text as valid source. Oracle requires the user's configured loader; no credentials are included.

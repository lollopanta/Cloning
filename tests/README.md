Run with Python 3 and the Luau CLI on PATH, or set LUAU and LUAU_COMPILE to their executable paths.

```
python tests/test-decompile-pool.py
python tests/test-prepass-gather.py
```

Tests extract the shipped helpers and exercise concurrency limits, timeouts, late returns, callbacks, export scope, ignore rules, and overrides.

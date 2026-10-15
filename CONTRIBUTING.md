# Contributing

Use Swift 6 with the macOS SDK. Keep platform-independent behavior in DS4Core and macOS effects in DS4Platform. Add a regression test for behavioral changes; use the real parser, gesture engine, configuration store, or local socket where possible.

Run `./scripts/check.sh` before proposing a change. Keep credentials and generated builds out of the repository. Document manual hardware checks separately from automated tests. Changes to protocol layout, contact handling, or output cleanup need a focused regression case and controller verification.

Source is licensed under MIT; contributions are made under the same license.

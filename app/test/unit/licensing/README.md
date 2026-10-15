LIC-02 tests use fake stores, deterministic clocks and JSON-roundtripped settings.
They do not substitute for StoreKit/Play sandbox results: those remain pending in
`docs/test-plans/device/LIC-02.md`. The `.storekit` file uses synthetic local-test
prices; production UI never embeds these amounts and queries localized prices.

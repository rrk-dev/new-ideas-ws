# LIC-02: deliberately exclude optional billing telemetry dependencies.
# Pinned Billing 9.1.0 disables its logger on missing transport classes.
# See docs/billing-sdk-audit.md; re-audit on every SDK update.
-dontwarn com.google.android.datatransport.**

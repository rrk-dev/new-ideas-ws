# Play Billing dependency audit — LIC-02

Inspected 2026-10-14: Google Maven `com.android.billingclient:billing:9.1.0`
(released 2026-06-18), Android SDK License. AAR SHA-256:
`d28286d4e4c18725510980de01211d9b72501e7146d96817fa0c9999af9b0d22`.
Source: https://dl.google.com/dl/android/maven2/com/android/billingclient/billing/9.1.0/billing-9.1.0.pom

The proprietary SDK source is not published. Inspected POM, manifest and class
constant pools / JVM bytecode. Manifest adds only billing permission, package
queries, two non-exported billing proxy activities and SDK version metadata.
No application analytics, crash SDK or recording/content API is used.

The POM includes DataTransport (API/runtime/CCT) and Play services location.
These are explicitly excluded from the Gradle billing dependency: they are not
allowed as client telemetry/network code. No analytics or location dependencies
are added by LIC-02. Keep Play services base/basement/tasks, which the billing
API references. Their use remains the store/billing integration only.

## Why telemetry exclusion is safe for this pinned artifact
`com.android.billingclient.api.zzdt` is the only class referencing
TransportRuntime. Its constructor has a catch-all handler around bytecode
positions 4 through 41 (length 50). Handler at 42 discards the throwable, sets
its disabled flag, and returns; it does not rethrow. Thus missing DataTransport
classes disable the logger. Its send method `zza` first checks that flag and
returns with a content-free logcat message when disabled. The remaining send
block at positions 15 through 27 also has a catch-all handler which logs only a
fixed failure message and returns. No code path rethrows missing-class errors.

The logger's bytecode was inspected directly in the published classes.jar:

```text
<init>(Context): 2ab700132bb800182ab8001cb20022b600261228122a122cb80032bb003459b70035b9003b0500b5003db1572a04b50041b1
zza(zzkw):       2ab4004199000b12441246b8004cb12ab4003d2bb80052b900580200b1571244125ab8004cb1
```

R8 gets a narrowly scoped `-dontwarn com.google.android.datatransport.**` for
these intentionally absent optional classes. This is **not** a general missing
class suppression. Location classes are not referenced by the billing artifact.
Re-audit this exclusion whenever the SDK version changes; do not silently bump
the pin or reintroduce transport dependencies. Device builds and egress capture
must confirm runtime behavior and the final resolved dependency/permission graph
before store submission; native Android tools are unavailable here.

## Cryptography and privacy
Play's signed purchase format requires SHA1withRSA verification with its console
RSA public key (2048-bit minimum); no SHA-1 signatures are created. This is a
protocol compatibility exception, not a new cryptographic protocol. The key is
build-injected and not committed; no private keys/certificates introduced.
StoreKit's `.verified` result performs Apple's JWS verification. No certificate
validation overrides or application HTTP clients. Last verification is stored
in SEC-01 encrypted settings; receipts, signatures and purchase tokens are not
persisted by Dart or logged. See ADR-LIC-02 and the device checklist for freshness
limitations and pending native/store verification.

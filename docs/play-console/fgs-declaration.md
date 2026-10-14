# Play Console — foreground service declaration (AUD-05)

Paste into Play Console → App content → **Foreground service permissions** when the first build
with `RecordingService` is uploaded (REL-05 owns the submission). Draft wording — product/legal
may edit; keep it truthful to the behaviour below.

## What the manifest declares
| Item | Value |
|---|---|
| Service | `com.vaultvoice.vaultvoice.RecordingService`, `exported=false` |
| `foregroundServiceType` | `microphone` (the only FGS in the app) |
| Permissions | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `RECORD_AUDIO`, `POST_NOTIFICATIONS` |
| Not declared | any other `FOREGROUND_SERVICE_*`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, phone/call-log permissions, `SYSTEM_ALERT_WINDOW`, accessibility (SEC-09 CI guard) |

Pinned by `app/test/unit/recording/recording_indicator_test.dart` (`[AUD-05/AC4]`) and
`tools/ci/check_recording_policy.sh` (incl. the merged manifest in the CI `android` job).

## Declaration text (FOREGROUND_SERVICE_MICROPHONE)
**Feature:** Voice note recording.

**Description:** VaultVoice records voice notes and meetings that the user starts by tapping
Record. While a recording is running the app uses a microphone foreground service so the recording
continues when the screen turns off or the user switches apps. An ongoing notification with Pause,
Resume and Stop is shown for the whole recording, and the recording stops when the user taps Stop
(or at the configured maximum length). The service is never started without the user's tap, is not
restarted by the system, and never records phone or VoIP calls: recording pauses when a call starts
and resumes only when the user taps Resume. Audio is processed on the device and is not uploaded.

**User impact if deferred / interrupted:** the user's recording would stop or lose audio as soon as
the screen turns off; a long meeting could not be recorded.

**Video (required):** screen recording of: tap Record in the app → notification appears → press
the power button (screen off) for 1 min → unlock → notification shows the running timer → tap
Pause, Resume, Stop in the notification → recording appears in the Library.
Store the video link in `docs/test-plans/device/evidence/AUD-05/`.

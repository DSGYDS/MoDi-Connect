# Android 1.0 release evidence

Last automated verification: 2026-08-20 (Asia/Shanghai)

## Automated verification

| Check | Official/Gitee edition | Community edition |
|---|---:|---:|
| `testDebugUnitTest` | PASS — 74/74 | PASS — 74/74 |
| `assembleDebug` | PASS | PASS |
| Protocol artifact | 0.1.1 / `690e322b7ed492c2454fd0684f28ab900eeae047` | same |
| Shared Android behavior | PASS | PASS |

The remaining source differences are intentional edition boundaries in update-check UI/runtime code. MediaProjection ownership, coroutine lifecycle, stream gain, mute recovery, failure classification, OEM guidance and onboarding are synchronized.

Debug APKs:

- Official/Gitee: `android/app/build/outputs/apk/debug/app-debug.apk`
- Community: `android/app/build/outputs/apk/debug/app-debug.apk`

## Device acceptance matrix

No physical Android devices or emulator matrix was available in this workspace. These checks are release blockers and remain **PENDING**, not inferred from unit tests.

| Matrix | Required checks | Status |
|---|---|---|
| API 29 | MediaProjection grant/stop; mic/system/mix; volume keys; normal stop; force-stop/relaunch volume recovery | PENDING |
| API 30 | Same as API 29 | PENDING |
| API 34 | Same, including foreground-service permission/type behavior | PENDING |
| API 36 | Same, including foreground-service permission/type behavior | PENDING |
| Xiaomi/Redmi | Vendor settings intent; 10-minute screen-off stream | PENDING |
| Huawei/Honor | Vendor settings intent; 10-minute screen-off stream | PENDING |
| OPPO/realme | Vendor settings intent; 10-minute screen-off stream | PENDING |
| vivo/iQOO | Vendor settings intent; 10-minute screen-off stream | PENDING |
| Samsung/stock | Vendor settings intent; 10-minute screen-off stream | PENDING |

For each device run, record model, Android/API version, route/link, start and stop timestamps, whether media volume was restored, resolved settings component, result, and a redacted log or screen recording reference.

## Implemented safeguards

- MediaProjection callback registration precedes consumption; replacement and system revocation are owned centrally.
- Production audio/handshake lifecycle contains no `runBlocking`.
- Hardware volume keys adjust stream gain only while streaming; gain persists and survives capturer restart.
- System-media mute is preceded by a durable recovery ledger; normal stop, service teardown and cold start restore it.
- Empty production catches were removed; stable failure codes survive export while credentials and device identifiers are redacted.
- OEM background guidance has application-details fallback, and first-run onboarding keeps permission launches user-driven.


+# Windows 1.0 release evidence

Recorded: 2026-08-20 (Asia/Shanghai)

## Automated verification

| Check | Result |
|---|---|
| Official Windows `dotnet test windows/MoDi.slnx --no-restore` | PASS — 285/285 (two consecutive final runs) |
| Community Windows `dotnet test windows/MoDi.slnx --no-restore` | PASS — 276/276 |
| Official Android `:app:testDebugUnitTest` | PASS — 55/55 |
| Community Android `:app:testDebugUnitTest` | PASS — 55/55 |
| Shared-source comparison | PASS — 415 controlled shared files, 0 normalized-content differences |
| Verification host | Windows 11 Home China, 10.0.26200 build 26200 |

Edition-only update implementation, edition content, composition wiring, generated output, and repository-policy tests are excluded from the shared-source comparison.

## Manual release matrix

Do not mark a row complete without a real redacted run. Record the OS build, app commit, device model/Android version, observed result, and evidence location.

| Scenario | Windows 10 | Windows 11 |
|---|---|---|
| Wi-Fi address change while resident receiver is running | PENDING | PENDING |
| Sleep/wake followed by LAN discovery | PENDING | PENDING |
| Three LAN disconnect/reconnect cycles without duplicate callbacks | PENDING | PENDING |
| Bluetooth disconnect during active read | PENDING | PENDING |
| USB disconnect during active read | PENDING | PENDING |
| Missing VB-CABLE onboarding diagnostic | PENDING | PENDING |
| UDP 12345/12347 blocked by firewall | PENDING | PENDING |
| Four-step onboarding can be skipped and stays completed after restart | PENDING | PENDING |

## Recording format

- OS/version:
- App edition and commit:
- Android device/version:
- Scenario:
- Expected:
- Observed:
- Result: PASS / FAIL
- Redacted evidence path:
- Notes:


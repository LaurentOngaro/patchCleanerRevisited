# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-07-18

### Added

- Pester test suite in `tests/` covering the three pure helper functions that
  carry the most safety-critical logic:
  - `tests/Compare-VersionString.Tests.ps1` (9 tests) - equality, inequality,
    and the anti-FP guards against the `8.0.1` vs `8.0.10`,
    `9.0` vs `9.0.18`, and `10.0.100` vs `10.0.1000` prefix-matching bugs.
  - `tests/Test-InstalledVersion.Tests.ps1` (8 tests) - empty / null inputs,
    positive matches across components, and the anti-FP guard that prevents
    flagging a live .NET runtime as a leftover.
  - `tests/Get-PackageKeywords.Tests.ps1` (10 tests) - extraction of primary
    keywords and version tokens, stop-word filtering, uniqueness, and the
    anti-FP guardrail that keeps `microsoft` from leaking into primary
    keywords (which would trigger false positives everywhere).
- `$env:PCREV_TEST_HARNESS` switch in `patchCleanerRevisited.ps1`: when set,
  the script returns just before `$window.ShowDialog()` so the Pester suite
  can dot-source production code without launching the WPF UI or touching
  the real filesystem / registry. The same switch is documented in
  `README.md` and `CONTRIBUTING.md` so contributors can extend the suite
  without duplicating function definitions.
- GitHub Actions workflow `.github/workflows/tests.yml` running the Pester
  suite on every push and pull request against `main`, on both Windows
  PowerShell 5.1 and PowerShell 7.

### Changed

- `README.md` now documents the test suite under a dedicated "Tests" section,
  with copy-paste instructions for running the suite locally
  (`Invoke-Pester -Path .\tests -Output Detailed`) and a reference to the
  CI workflow badge equivalent in the project description.
- `CONTRIBUTING.md` step 4 was updated to point contributors at the
  `PCREV_TEST_HARNESS` pattern when adding new tests, instead of asking
  them to invent their own harness.

## [1.0.1] - 2026-07-18

- chore: No changes

### Fixed

- Removed the "No automated test suite yet" line from the
  `Known limitations` of the 1.0.0 release notes, since 1.0.1 ships one.

## [1.0.0] - 2026-07-18

### Added

- Sponsored links (GitHub Sponsors, Patreon, Ko-fi, Tipeee) in the README.
- OSS project files: `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `SUPPORT.md`, `SPONSORS.md`, `.editorconfig`, `.gitattributes`, `.github/` templates.
- First public release under the `patchCleanerRevisited` name.
- Transparent single-script PowerShell + WPF UI for inspecting the
  `C:\Windows\Installer` cache.
- Orphan detection against the Windows Installer database via the
  `WindowsInstaller.Installer` COM API.
- Optional Deep Scan with Authenticode signer information.
- Configurable exclusions with `Adobe` preconfigured.
- .NET cleanup workflow: groups packages by product and major.minor branch,
  keeps the latest patch revision, defaults to dry-run mode.
- Leftovers Scanner with confidence-scored review for canonical .NET, NuGet,
  VS Packages, Package Cache, and registry locations.
- Component-wise version comparison (`Compare-VersionString`) to avoid
  `8.0.1` vs `8.0.10` false positives.
- Optional system restore-point creation before destructive operations.
- Text and structured JSON exports of installer and leftover lists.
- Reload-from-JSON support in both the main list and the Leftovers Scanner.
- Local-only operation: no installer, no bundled executable, no network call,
  no analytics, no account system.

### Known limitations

- Cleanup actions are destructive; no move/quarantine workflow yet.
- Leftover detection is heuristic and requires manual review.
- The GUI and PowerShell code are English-only.
- No automated test suite yet.

[1.0.0]: https://github.com/LaurentOngaro/patchCleanerRevisited/releases/tag/v1.0.0

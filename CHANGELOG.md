# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

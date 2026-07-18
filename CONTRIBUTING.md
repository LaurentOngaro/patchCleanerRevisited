# Contributing to PatchCleaner Revisited

Thanks for your interest in PatchCleaner Revisited! This project is **free, open-source, MIT-licensed, ad-free, tracker-free**. Contributions are welcome and appreciated.

## Before you start

- **Read the Security and Backup Disclaimer** in [`README.md`](README.md#security-and-backup-disclaimer). PatchCleaner Revisited modifies `C:\Windows\Installer`, the Windows Installer database, and the registry. A bug here can break application repair, updates, or uninstallation on real users' machines.
- **Run the script with `-Help` first** to familiarise yourself with the public surface, or read [`Get-Help`](https://learn.microsoft.com/powershell/scripting/learn/shell/using-the-help-system):

  ```powershell
  Get-Help .\patchCleanerRevisited.ps1 -Full
  ```

## How to contribute

1. **Open an issue first** for non-trivial changes (new feature, refactor, dependency addition) so we can agree on the design before you invest time in code.
2. **Fork the repository** and create a feature branch:

   ```bash
   git checkout -b feature/short-description
   ```

3. **Make your changes** in small, focused commits. Use the existing code style: 2-space indent, UTF-8 BOM for `.ps1` files, CRLF line endings.
4. **Add or update tests** when you fix a bug or change detection logic. The `tests/` folder is the target. If you do not know how to test the GUI, write a Pester test for the helper functions (`Get-PackageKeywords`, `Compare-VersionString`, `Test-InstalledVersion`, `Search-FileSystemLeftovers`, `Search-RegistryLeftovers`).
5. **Update `CHANGELOG.md`** under the `[Unreleased]` section.
6. **Open a Pull Request** using the provided template. Link the related issue with `Closes #NNN` or `Refs #NNN`.

## Coding conventions

- PowerShell files in this project use **UTF-8 with BOM** and **CRLF** line endings. Keep them that way so the UI glyphs (`↻`, ellipsis, quotes) render correctly on Windows PowerShell 5.1.
- Use `Set-StrictMode -Version Latest` in new functions to catch uninitialized variables early.
- Never `Invoke-Expression` on user-controlled strings. The script runs elevated.
- Prefer `Test-Path -LiteralPath`, `Remove-Item -LiteralPath`, `Get-ChildItem -LiteralPath` whenever paths may contain `[`, `]`, `{`, or `}` (Package Cache GUIDs).
- All destructive actions require a confirmation dialog. Keep that pattern when adding new entry points.
- Do not introduce network calls, telemetry, account systems, or analytics. The project is local-only by design.
- Expose user-visible strings through a single location if you intend to localise the UI later. For now, English is fine but keep it consistent.

## Reporting bugs

Use the **Bug report** issue template. Include:

- Windows version and build (`winver`)
- PowerShell version (`$PSVersionTable.PSVersion`)
- The exact error message and stack trace
- Whether you are running inside PowerShell 5.1 or PowerShell 7
- A screenshot of the dialog or window when relevant

## Proposing features

Use the **Feature request** issue template. Explain:

- The problem you are trying to solve
- The proposed user-facing behaviour
- Why the current workflow is insufficient
- Any alternative tools you have already tried

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Security

If you discover a security vulnerability, **do not open a public issue**. Follow the disclosure process in [`SECURITY.md`](SECURITY.md).

## Licence

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

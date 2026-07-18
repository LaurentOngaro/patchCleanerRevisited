# PatchCleaner Revisited

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) [![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell) [![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows/) [![GitHub stars](https://img.shields.io/github/stars/LaurentOngaro/patchCleanerRevisited?style=social)](https://github.com/LaurentOngaro/patchCleanerRevisited/stargazers) [![Sponsor this project](https://img.shields.io/badge/sponsor-%E2%9D%A4-ff6f61)](#sponsoring)

**Reclaim gigabytes from `C:\Windows\Installer` - read the code first, decide what to remove second.**

PatchCleaner Revisited is a **transparent single-script PowerShell + WPF tool** that helps advanced Windows users inspect MSI/MSP caches, review older .NET packages, and investigate leftovers before any cleanup. No installer, no bundled binary, no background service, no network call - just one `.ps1` file you can read end-to-end.

Built as a **modern, audit-friendly alternative** to [HomeDev's PatchCleaner](https://www.homedev.com.au/Free/PatchCleaner), which has been unmaintained since 2016 (latest release `1.4.2.0`, dependent on .NET Framework 4.5.2 and VBScript-based WMI, frequently flagged by antivirus, and not fully compatible with recent Windows builds).

> **Warning**
> This is a system-maintenance tool, not a one-click cleaner. Removing a required MSI/MSP file can break application repair, updates, or uninstallation. Start with a dry run, review every selection, export the results, and keep a tested system backup.

## Security and Backup Disclaimer

This script requires **Administrator privileges** and performs operations that can affect the Windows Installer database, the registry, and files under `C:\Windows\Installer`. Even with built-in safeguards, a misunderstanding, an edge case, or a Windows API regression can cause applications to fail repair, update, or uninstall.

Before running any non-dry-run action, complete **all** of the following steps:

1. **Create a full system image backup.** Use a tool such as Windows Backup, Macrium Reflect, Acronis, or Veeam, and store the backup on a separate drive or network location. Verify that the backup is restorable, not just created.
2. **Create a fresh system restore point.** Enable **Create restore point** in the application before any destructive operation, or run `Checkpoint-Computer -Description "Before PatchCleaner Revisited"` from an elevated PowerShell prompt.
3. **Test your backups and restore point.** A backup that has never been used to restore a system is not a reliable backup.
4. **Run a dry run first.** Review every selection, export it, and confirm the items match what you expect before unchecking dry-run mode.
5. **Keep the script source under review.** Anyone running this in a multi-user or production environment should read the full PowerShell file first; it is intentionally short and unminified so it can be audited.
6. **Do not run untrusted forks.** Use only the official repository at `https://github.com/LaurentOngaro/patchCleanerRevisited`.

The author and contributors provide this software **as is**, without any warranty of any kind. By running it you accept full responsibility for any change made to your system.

## Why this project exists

Windows stores cached `.msi` installers and `.msp` patches in `C:\Windows\Installer`. These files are often required later to repair, update, or uninstall applications. Over time, however, files that are no longer referenced can remain in the cache and consume significant disk space.

[PatchCleaner by HomeDev](https://www.homedev.com.au/Free/PatchCleaner) pioneered an accessible solution to this problem: compare the files in the Installer directory with the products and patches registered by Windows, then move or delete files considered orphaned.

PatchCleaner Revisited is an **independent project inspired by that original idea**. It keeps the same understandable foundation while exploring a modern, script-first workflow for technical users.

## A modern alternative to PatchCleaner

The original [PatchCleaner by HomeDev](https://www.homedev.com.au/Free/PatchCleaner) was a great tool for its time and pioneered the move-first workflow that still inspires safer cache cleanup today. **However, the original PatchCleaner is no longer maintained**: its latest public release (1.4.2.0) dates back to 2016, depends on .NET Framework 4.5.2 and VBScript-based WMI queries, is distributed as an unsigned installer, and is frequently flagged by modern antivirus products. It also relies on assumptions that no longer match recent versions of Windows, where the Windows Installer database, .NET installation layout, and protective permissions around `C:\Windows\Installer` have evolved significantly.

PatchCleaner Revisited addresses those gaps with a transparent, script-first workflow that targets current Windows releases. The original PatchCleaner remains an important reference and its **move-first workflow is an excellent safety feature**; if that feature is critical to you and your machine is still compatible with the legacy tool, you may prefer to keep using it. Otherwise, PatchCleaner Revisited is a useful modern alternative when you want:

- **Auditable source:** the complete application is one PowerShell script rather than an opaque installed binary.
- **No VBScript dependency:** installer information is read through the `WindowsInstaller.Installer` COM API.
- **Focused .NET maintenance:** older patch revisions can be grouped by product and version branch while retaining the latest revision found in each group.
- **Dry-run-first review:** .NET cleanup starts in dry-run mode and selects candidates without deleting them.
- **More context:** inspect registered and orphaned packages, metadata, Authenticode signer information, file size, date, and full path.
- **Configurable exclusions:** protect matching vendors or products; `Adobe` is excluded by default.
- **Leftover investigation:** search selected .NET-related locations and registry hives using confidence scores and explicit false-positive guards.
- **Reviewable exports:** save installer lists as text or structured JSON, then reload leftover lists later.
- **Additional safeguards:** optional restore points, confirmation dialogs, a critical warning before raw deletion of registered packages, and registry export before registry-key removal.
- **Local operation:** the current script contains no analytics, account system, or outgoing network request.

### Quick comparison

| Concern                  | HomeDev PatchCleaner (1.4.2.0, 2016) | PatchCleaner Revisited                                     |
| ------------------------ | ------------------------------------ | ---------------------------------------------------------- |
| Latest release | 2016 (no maintenance since) | Active development |
| Code transparency        | Closed binary installer              | One PowerShell script, fully readable                      |
| Windows Installer access | VBScript + WMI                       | `WindowsInstaller.Installer` COM API                       |
| .NET package cleanup     | Not specialized                      | Grouped by product and major.minor, dry-run first          |
| Leftover investigation   | Not included                         | Confidence-scored scan with explicit false-positive guards |
| Move/quarantine workflow | Yes (signature feature)              | **No** - destructive actions only                          |
| Restore-point prompt     | No                                   | Optional one-click creation                                |
| Exclusions               | Keyword-based                        | Keyword-based, `Adobe` preconfigured                       |
| Exports                  | Text only                            | Text + structured JSON                                     |
| Cost                     | Free, unsigned (AV flags)            | Free, MIT, no executable shipped                           |

### Important difference

PatchCleaner Revisited currently **does not provide a move/quarantine action for MSI/MSP files**. File and folder deletions are destructive. If a reversible move-first workflow is your priority, the original [PatchCleaner](https://www.homedev.com.au/Free/PatchCleaner) may be the better choice.

This project is not affiliated with, endorsed by, or a replacement for HomeDev's PatchCleaner.

## Features

### Windows Installer inventory

- Compares cached MSI/MSP files with products and patches known to Windows Installer.
- Shows orphaned files by default, with an option to include registered packages.
- Reads installer metadata such as title, subject, author, comments, product codes, and dates.
- Supports sortable columns, text filtering, selected-only filtering, and batch selection.
- Offers an optional deep scan for Authenticode signer information.

### .NET package cleanup

- Recognizes versioned .NET, Windows Desktop Runtime, and targeting-pack entries.
- Groups packages by product and major/minor branch.
- Keeps the latest patch revision detected in each group.
- Enables dry-run mode by default so candidates can be reviewed first.
- Can optionally ask `msiexec` to uninstall registered packages before removing cached files.
- Keeps files when `msiexec` reports an unexpected failure.

### Leftovers Scanner

- Searches canonical .NET, NuGet, Visual Studio package, Package Cache, and registry locations.
- Requires meaningful package-name matches and, where available, matching versions.
- Compares versions component by component, avoiding prefix confusion such as `8.0.1` versus `8.0.10`.
- Excludes versions still detected in active .NET installation directories.
- Assigns confidence scores and leaves weaker matches for manual selection.
- Exports registry keys to `.reg` files before deleting them.
- Exports and reloads JSON review lists.

### Safety controls

- Nothing is deleted during a normal scan.
- .NET dry run is enabled by default.
- Destructive actions require confirmation.
- Raw deletion of registered packages triggers an additional critical warning.
- System restore point creation can be enabled before package changes.
- Exclusions can prevent known vendors or products from appearing as cleanup candidates.
- Progress and per-item errors remain visible during batch operations.

A restore point is not a substitute for a full backup, and folder deletions performed by the Leftovers Scanner are not automatically backed up.

## Requirements

- Windows with the Windows Installer service and WPF support; Windows 10 or 11 is recommended.
- Windows PowerShell 5.1 or PowerShell 7 on Windows.
- Administrator privileges to inspect and modify protected installer files.
- System Protection enabled if you want to create restore points.

No separate application installation or package dependency is required.

## Quick start

### 1. Get the project

```powershell
git clone https://github.com/LaurentOngaro/patchCleanerRevisited.git
cd patchCleanerRevisited
```

Alternatively, download the repository as a ZIP and extract it.

### 2. Open PowerShell as Administrator

The script needs elevated rights to access protected Windows Installer data and perform cleanup operations.

### 3. Allow the script for this session and launch it

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\patchCleanerRevisited.ps1
```

Display the built-in comment-based help without opening the interface:

```powershell
Get-Help .\patchCleanerRevisited.ps1 -Full
```

## Recommended workflow

1. Create or verify a full system backup.
2. Launch the script as Administrator.
3. Keep **Deep Scan** enabled and add any exclusions relevant to your machine.
4. Click **Scan**; do not select **Show registered installers** unless you need that diagnostic view.
5. Review package names, status, paths, signer information, and sizes.
6. Export the candidate list before making changes.
7. For .NET cleanup, leave **Dry run** enabled on the first pass.
8. Enable **Create restore point** before any destructive operation.
9. Delete only entries you have independently confirmed are no longer required.
10. Reboot and verify application repair, update, and uninstall workflows before reclaiming backups.

## How it works

```text
Windows Installer COM database
              |
              v
 Registered MSI/MSP cache paths ----+
                                     | compare
 C:\Windows\Installer files --------+
              |
              v
    Orphaned / registered view
              |
              +--> manual review and export
              +--> optional .NET grouping and dry run
              +--> optional, confirmed cleanup
              +--> optional leftover review
```

The main orphan detection remains intentionally simple: a cache file is considered orphaned when its path is not present among the local package paths reported by Windows Installer. Metadata, signatures, exclusions, and specialized .NET checks add context, but no heuristic can guarantee that every candidate is safe to remove.

## Development notes

PatchCleaner Revisited was developed with the help of an AI coding assistant. The assistant was used to reason through the Windows Installer workflow, structure and review the PowerShell/WPF implementation, strengthen safeguards around version matching and destructive operations, and prepare the project documentation. Every code path was reviewed by a human before being merged.

If you spot a defect introduced or amplified by the AI-assisted workflow, please open an issue — see [`SUPPORT.md`](SUPPORT.md) for the right channel.

## Current limitations

- Cleanup actions can be irreversible; there is no built-in MSI/MSP quarantine or undo feature.
- Detection quality depends on the information exposed by Windows Installer and package metadata.
- The .NET cleaner recognizes specific subject/version naming patterns and may not classify every package.
- Leftover detection is heuristic and requires manual review even when a confidence score is high.
- Registry exports are created before registry deletion, but deleted folders are not backed up.
- The graphical interface and implementation are currently English-only.
- There is not yet an automated test suite or signed release binary.

## Roadmap

- **Move / quarantine workflow** for MSI/MSP files, inspired by the original PatchCleaner safety feature.
- **Per-package backup of cached installers** to a user-chosen directory before any deletion.
- **Portable ZIP release** with a launcher that requests elevation only when needed.
- **Localized UI** (French first, then community contributions).
- **Pester-based test suite** covering the keyword extraction, version comparison, and exclusion logic.
- **Signed release binary** for users who prefer a single-file download.

## Other projects by the same author

If you care about transparent, local-first developer tools, you may also like:

- **[AIFlowBridge](https://github.com/LaurentOngaro/AIFlowBridge)** - A multi-provider AI coding assistant with a transparent vision proxy, usage metrics, and an OpenAI-compatible local gateway. Runs as a VS Code extension or as a standalone Node.js binary (~30 MB RAM), exposes 100+ models via OpenRouter plus direct vendors (DeepSeek, MiniMax, Xiaomi MiMo), and never phones home.

Both projects follow the same philosophy: **free, open-source, MIT, ad-free, tracker-free, no data collection.**

## Sponsoring

PatchCleaner Revisited is **free, open-source, ad-free, tracker-free**. It will never ask you to pay for a feature, show you ads, or phone home. Sponsorship funds the whole body of work - not just this script.

If PatchCleaner Revisited (or any of my other projects) saved you time or helped you reclaim disk space, please consider supporting development:

- **GitHub Sponsors** - https://github.com/sponsors/LaurentOngaro
- **Patreon** - https://www.patreon.com/LaurentOngaro
- **Ko-fi** - https://ko-fi.com/LaurentOngaro
- **Tipeee (FR)** - https://fr.tipeee.com/laurentongaro

Sponsors are listed in the dedicated `SPONSORS.md` file once the project reaches its first recurring contributors. Recurring support is preferred over one-off donations because it lets me plan multi-month maintenance windows around the .NET release cycle.

## Acknowledgements

PatchCleaner Revisited explicitly acknowledges [HomeDev's PatchCleaner](https://www.homedev.com.au/Free/PatchCleaner), which demonstrated both the value of identifying orphaned Windows Installer cache files and the importance of offering cautious recovery options.

The projects are independent. The PatchCleaner name and original application belong to their respective owner.

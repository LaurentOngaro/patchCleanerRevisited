# Security Policy

## Scope

PatchCleaner Revisited is a single PowerShell script that:

- Reads the Windows Installer database via the `WindowsInstaller.Installer` COM API.
- Reads metadata and Authenticode signatures from cached MSI/MSP files.
- Reads from and writes to `C:\Windows\Installer`, the registry, and the user's local profile.
- May delete files and registry keys **only after explicit user confirmation**.

It runs **locally only**. It does not open network sockets, send telemetry, or contact any remote service.

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email me directly (check my profile), or use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability).

Please include:

- A clear description of the issue and the attack scenario
- The affected commit or release tag
- Reproduction steps, ideally with the exact command-line invocation
- Whether you were able to confirm the issue on a non-production machine
- Your contact details for follow-up questions

You can expect an initial response within **7 days**. If we can confirm the issue, we will:

1. Work with you on a coordinated disclosure timeline.
2. Ship a fix on a private branch, then publish a release once you have had a reasonable window to review the patch.
3. Credit you in the release notes and in the `CHANGELOG.md` unless you prefer to stay anonymous.

## Out-of-scope reports

- Reports against forks or modified copies of the script. We only support the source tree on the official repository.
- Reports against the original HomeDev PatchCleaner. This is a separate project.
- Feature requests or general usability feedback. Please use GitHub Discussions or the issue tracker instead.

## Hardening checklist (for users)

Before running the script on a production machine, make sure you:

1. Download the script **only** from `https://github.com/LaurentOngaro/patchCleanerRevisited`.
2. Verify the commit hash shown in the terminal matches the hash on the release page.
3. Run the script with `-Help` first to inspect the parameter surface.
4. Create a full system image backup and a system restore point before any non-dry-run action.
5. Read the [Security and Backup Disclaimer](README.md#security-and-backup-disclaimer) in full.

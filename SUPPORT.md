# Support

## Documentation

Start with the [`README.md`](README.md). It covers installation, the recommended
workflow, the security and backup disclaimer, and the comparison with the
original PatchCleaner.

For the in-script help, run:

```powershell
Get-Help .\patchCleanerRevisited.ps1 -Full
```

## Where to ask

| Channel                                                                                  | When to use                                                                      |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| [GitHub Discussions](https://github.com/LaurentOngaro/patchCleanerRevisited/discussions) | General questions, ideas, "how do I…", sharing your workflow                     |
| [GitHub Issues / Bug report](../../issues/new?template=bug_report.md)                    | Confirmed bugs with reproduction steps                                           |
| [GitHub Issues / Feature request](../../issues/new?template=feature_request.md)          | New functionality proposals                                                      |
| [Security disclosure](SECURITY.md)                                                       | Anything that could be a security vulnerability - **do not open a public issue** |
| [Author's other projects](https://github.com/LaurentOngaro)                              | Unrelated topics                                                                 |

## Before opening a new discussion or issue

Please include:

1. The exact PowerShell version (`$PSVersionTable.PSVersion`)
2. The Windows build (`winver` output)
3. The commit hash or release tag you are running
4. The exact error message, if any
5. The full command-line you used, with the `-Help` output when relevant

## What this project does not support

- The original [HomeDev PatchCleaner](https://www.homedev.com.au/Free/PatchCleaner).
  For that project, contact its author. PatchCleaner Revisited is an independent
  reimplementation inspired by the same idea; the two projects share no code.
- Custom forks or downstream distributions. Please reach out to the maintainer
  of the fork instead.

## Commercial support

There is no paid support channel. The author maintains this project on a
best-effort basis alongside other open-source work. If you need a guaranteed
response time, you can sponsor the project on GitHub Sponsors to fund a
maintenance window, but this is not a service-level agreement.

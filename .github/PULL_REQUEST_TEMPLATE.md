# Pull Request

Thanks for contributing to PatchCleaner Revisited.

## Linked issue

- Fixes / Closes / Refs: #NNN

## Summary

What does this PR do, and why?

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing behaviour to change)
- [ ] Documentation only

## Checklist

- [ ] I have read [`CONTRIBUTING.md`](../CONTRIBUTING.md)
- [ ] I have read the [Security and Backup Disclaimer](../README.md#security-and-backup-disclaimer)
- [ ] I have tested the change on a non-production Windows machine
- [ ] I ran the script with `-Help` to verify it still parses
- [ ] I added or updated Pester tests in `tests/` when relevant
- [ ] I updated `CHANGELOG.md` under `[Unreleased]`
- [ ] I followed the existing code style (UTF-8 BOM, CRLF, 2-space indent)
- [ ] I did not introduce a network call, telemetry, or analytics
- [ ] I did not change destructive behaviour without updating the confirmation dialog

## Manual test plan

Describe the steps you ran on your machine:

1.
2.
3.

## Screenshots

If the change affects the UI, attach before/after screenshots. Do not include
sensitive information from your system.

## Risk assessment

- [ ] Low - no destructive code paths affected
- [ ] Medium - touches file-system or registry paths but no destruction
- [ ] High - modifies destructive operations; requires maintainer review

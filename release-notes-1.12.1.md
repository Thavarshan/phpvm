# Release Notes for v1.12.1

## Summary

This release adds the new `phpvm self-update` command, enabling users to update phpvm to the latest stable version directly from the command line.

## Changes

- Added `phpvm self-update` to automatically download and install the latest stable phpvm script.
- Updated `README.md` to document the new self-update command.
- Added changelog entry for the self-update feature.

## Notes

Run the release creation command after pushing the branch:

```sh
gh release create 1.12.1 --title "v1.12.1" --notes-file release-notes-1.12.1.md
```

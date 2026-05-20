# v1.12.0 Release Notes

## Added

- Add `latest-remote` keyword for `phpvm install`, allowing users to install the newest available PHP version from remote package manager repositories.
- Add `latest-available` alias for `latest-remote`.

## Details

- `phpvm install latest-remote`
- `phpvm install latest-available`

## Notes

- This feature works with existing package manager support for Homebrew, apt, dnf, yum, and pacman.
- It complements `phpvm ls-remote`, which lists available remote versions.
- In test mode, the remote version list is simulated for coverage.

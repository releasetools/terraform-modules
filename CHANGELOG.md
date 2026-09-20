# Changelog

## 0.3.0 - 2026-09-20

### Changed

The github-repo module's default ruleset requires linear, signed history
and pull requests, permits squash and rebase merges, and blocks deletion
and force pushes. The ruleset input exposes the settings supported by the
GitHub provider. To permit merge commits, remove
required_linear_history from ruleset.rules and set
ruleset_allowed_merge_methods to ["squash", "merge"]. The module uses the
GitHub provider and preserves the existing ruleset resource address. Dismissal
restrictions and extra approval for unattributed changes remain outside
Terraform's control. GitHub provider 6.13 or later within version 6 is required.

### Added

New GitHub Apps request permission to open pull requests. Existing Apps
need that permission enabled in their settings and approved on each installation.

## 0.2.0 - 2026-09-20

### Changed

New GitHub Apps request write access to repository contents so automation
can push commits. Existing Apps need that permission enabled in their settings
and approved on each installation.

## 0.1.0 - 2026-06-18

### Added

The `github-repo` module configures repositories and their branch rules.
The `github-app` module creates automation Apps and manages installation access.

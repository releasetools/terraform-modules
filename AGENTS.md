# AGENTS.md

A monorepo of reusable Terraform modules for `releasetools`. Each module lives
under `modules/<name>/` and is referenced with the `//modules/<name>` subdirectory
path plus a `?ref=` tag.

## What to know

- Modules, not root configs: no `provider` or `backend` blocks. The caller wires
  those.
- One tag stream covers every module. A single tag (`v0.1.0`) pins the whole repo;
  a consumer bumping `?ref=` moves all the modules it uses together. Size the bump
  to the biggest change across the modules touched.
- `modules/github-repo` creates and configures a repository (settings, labels,
  environments, Actions permissions, branch ruleset) and optionally checks that
  required Actions secrets exist.
- `modules/github-app` is the tooling for the shared automation App: create it
  from a manifest, store credentials, and manage installation repo access.
  Managing repository **environments** needs the App's `actions` permission, not
  just `administration` — GitHub gates the environments API behind Actions.

## Working here

- Run `terraform fmt` and `terraform validate` in the module you changed before
  committing.
- Keep prose plain and human; avoid AI tells. Give docs a humanizer pass.
- Release with semver tags (`v0.1.0`); consumers pin `?ref=`. Update the module's
  README in the same change as the code.

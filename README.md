# terraform-modules

Reusable Terraform modules for `releasetools`, kept in one repo so a change that
spans more than one module is a single PR and a single tag.

## Modules

| Module | What it does |
|---|---|
| [`github-repo`](modules/github-repo) | Create and configure a GitHub repository: settings, labels, environments, Actions permissions, and a branch ruleset. Optionally checks that required Actions secrets exist. |
| [`github-app`](modules/github-app) | Tooling for a shared GitHub App that automates repositories — create it from a manifest, store its credentials, and manage which repos its installation can reach. |

## Referencing a module

Point `source` at the repo and the module's subdirectory with the `//` separator,
and pin a tag with `?ref=`:

```hcl
module "repo" {
  source = "git::https://github.com/releasetools/terraform-modules.git//modules/github-repo?ref=v0.2.0"
  # ...
}
```

Each module's own README has the full input/output reference.

## Versioning

One tag stream covers every module. A tag like `v0.1.0` pins the whole repo, so a
consumer that bumps `?ref=` moves all the modules it uses together. Release with
semver tags; consumers pin `?ref=`.

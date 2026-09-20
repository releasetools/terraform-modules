# ruleset

Applies a branch ruleset to an existing GitHub repository using the GitHub
provider. `github-repo` calls this submodule by default. Call it directly to
manage rules on a repository without managing its other settings.

## Usage

```hcl
provider "github" {
  owner = "releasetools"
}

module "main_rules" {
  source = "git::ssh://git@github.com/releasetools/terraform-modules.git//modules/github-repo/modules/ruleset?ref=v0.3.0"

  repository = "homebrew-tap"
}
```

The example targets the pending `v0.3.0` release. Until it is tagged, use a local
checkout as the module source. The caller supplies the configured GitHub provider.

`repository` is the only required input. The typed `ruleset` input in
[`variables.tf`](variables.tf) defines the configuration and its defaults.
Passing `null` uses those defaults.

## Defaults

The submodule applies the `main` ruleset to the supplied repository. The
`ruleset` variable holds the provider-supported configuration captured from
[`releasetools/homebrew-tap` ruleset 23733932](https://github.com/releasetools/homebrew-tap/rules/23733932)
on 2026-09-20, in GitHub's API shape. It contains the writable configuration;
repository identity, timestamps, and other response metadata are omitted.

| Setting | Default |
| --- | --- |
| Enforcement | `active` |
| Branches | `include = ["~DEFAULT_BRANCH"]`, `exclude = []` |
| Bypass actors | None |
| Deletion and force pushes | Blocked |
| Linear history and signed commits | Required |
| Pull requests | Required, with 0 approving reviews |
| Merge methods | `squash`, `rebase` |
| Stale review dismissal, code owner review, last push approval, resolved review threads | All `false` |
| Required reviewers | None |

The repository must enable the merge methods callers want to use. The ruleset
blocks merge commits on matching branches even when the repository enables
that button. This submodule manages only the ruleset.

Copy the `ruleset` default from `variables.tf` to customize the managed settings.
Its `rules` list supports the five captured rule types. Omitting a rule removes
that requirement. These inputs take precedence over the object:

| Input | Behavior |
| --- | --- |
| `ruleset_enforcement` | Override enforcement; `null` uses the object |
| `ruleset_require_pull_request = false` | Omit the pull request rule |
| `ruleset_required_signatures` | Override the signature requirement; `null` uses the object |
| `ruleset_allowed_merge_methods` | Override the pull request merge methods; `null` uses the object |

For example, seeding a repository with existing history uses:

```hcl
ruleset_enforcement = "disabled"
```

Set it to `"active"` after pushing the history.

### Unmanaged review settings

`dismissal_restriction` and `require_extra_approval_for_unattributed_changes`
are omitted from the module's inputs because the
[GitHub provider schema](https://github.com/integrations/terraform-provider-github/blob/v6.13.0/github/resource_github_repository_ruleset.go)
does not expose them. Terraform neither configures them nor detects their drift.
GitHub determines their values when the request omits them; omission does not
mean disabling either setting.

The captured source ruleset has dismissal restrictions disabled and extra
approval for unattributed changes enabled.
[captured-main-ruleset.json](captured-main-ruleset.json) records those values
as reference data; the module manages the remaining settings.

### Existing rulesets

Import a ruleset already on a repository before applying this module to it:

```sh
terraform import 'module.main_rules.github_repository_ruleset.main' homebrew-tap:23733932
```

Adjust the module address and repository name to match the caller. The repository
can be managed separately or created outside Terraform.

## Requirements

- Terraform >= 1.10
- `integrations/github` ~> 6.13

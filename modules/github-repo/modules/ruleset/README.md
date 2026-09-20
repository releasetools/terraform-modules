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

  repository = "my-service"
}
```

The example targets the pending `v0.3.0` release. Until it is tagged, use a local
checkout as the module source. The caller supplies the configured GitHub provider.

`repository` is the only required input. The typed `ruleset` input in
[`variables.tf`](variables.tf) defines the configuration and its defaults.
Passing `null` uses those defaults.

## Defaults

The submodule applies the `main` ruleset to the supplied repository. The
`ruleset` variable holds writable settings in GitHub's API shape.

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
| Required status checks | None |

The repository must enable the merge methods callers want to use. The ruleset
blocks merge commits on matching branches even when the repository enables
that button. This submodule manages only the ruleset.

Copy the `ruleset` default from `variables.tf` to customize the managed settings.
Its `rules` list supports `deletion`, `non_fast_forward`, `required_linear_history`,
`required_signatures`, `pull_request`, and `required_status_checks`. Omitting a rule
removes that requirement. These inputs take precedence over the object:

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

### Required status checks

Add a `required_status_checks` entry to `ruleset.rules`. The module creates a
provider `required_check` block for each check. Names and optional integration
IDs can come from caller variables or other Terraform expressions.

This example keeps the default protections and requires `allow`:

```hcl
variable "required_checks" {
  type = list(object({
    context        = string
    integration_id = optional(number)
  }))
  default = [{ context = "allow", integration_id = 15368 }]
}

module "main_rules" {
  source = "git::ssh://git@github.com/releasetools/terraform-modules.git//modules/github-repo/modules/ruleset?ref=v0.3.0"

  repository = "my-service"
  ruleset = {
    name        = "main"
    target      = "branch"
    enforcement = "active"
    conditions = {
      ref_name = { include = ["~DEFAULT_BRANCH"], exclude = [] }
    }
    bypass_actors = []
    rules = [
      { type = "deletion" },
      { type = "non_fast_forward" },
      { type = "required_linear_history" },
      { type = "required_signatures" },
      { type = "pull_request", parameters = {} },
      {
        type = "required_status_checks"
        parameters = {
          strict_required_status_checks_policy = false
          do_not_enforce_on_create              = false
          required_status_checks               = var.required_checks
        }
      },
    ]
  }
}
```

The same `ruleset` object works with the parent `github-repo` module.
An empty pull request `parameters` object uses the defaults shown above.

`integration_id` is optional. Set it to require the check from a particular
GitHub App. The two policy flags default to `false`: checks need not run against
the latest target branch, and GitHub enforces them on branch creation.

A status-check rule requires at least one check with a nonempty `context`.
Omit the rule to require no checks. This module configures the requirement;
the repository's CI must publish the named check.

### Unmanaged review settings

`dismissal_restriction` and `require_extra_approval_for_unattributed_changes`
are omitted from the module's inputs because the
[GitHub provider schema](https://github.com/integrations/terraform-provider-github/blob/v6.13.0/github/resource_github_repository_ruleset.go)
does not expose them. Terraform neither configures them nor detects their drift.
GitHub determines their values when the request omits them; omission does not
mean disabling either setting.

### Existing rulesets

Import a ruleset already on a repository before applying this module to it:

```sh
terraform import 'module.main_rules.github_repository_ruleset.main' my-service:123456
```

Adjust the module address and repository name to match the caller. The repository
can be managed separately or created outside Terraform.

## Requirements

- Terraform >= 1.10
- `integrations/github` ~> 6.13

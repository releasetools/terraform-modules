# github-repo

A Terraform module that creates a GitHub repository and configures it (labels,
environments, Actions permissions, a branch ruleset) in one apply. It can also
confirm that the Actions secrets a repo's workflows need are present.

## Usage

```hcl
provider "github" {
  owner = "your-org"
}

module "repo" {
  source = "git::https://github.com/releasetools/terraform-modules.git//modules/github-repo?ref=v0.3.0"

  github_owner = "your-org"
  name         = "my-service"
  description  = "What this repo is for."
  visibility   = "private"
}
```

The example targets the pending `v0.3.0` release. Until it is tagged, use a local
checkout as the module source.

You supply the `github` provider and any backend. The module has no provider or
backend blocks of its own.

## One apply, no stages

The resources reference the repository directly, and the optional secret check's
data source `depends_on` it, so that read happens during apply, after the repo
exists. A single apply both creates the repo and checks it.

The branch ruleset would block pushing existing history, so seeding is a toggle:
apply with `ruleset_enforcement = "disabled"`, push your history, then apply with
`"active"`. A brand-new repo with nothing to import just needs one apply.

## The secret check (opt-in)

Set `required_secrets` to the names your workflows expect:

```hcl
required_secrets = ["DEPLOY_KEY", "NPM_TOKEN"]
```

The module then confirms each one exists at the repo or org level and warns about
any that are missing. It reads names, never values, so it needs `Secrets: read`
(and `Organization secrets: read` for an org owner), not an admin role. The
owner type is detected automatically. Leave it empty (the default) to skip the
check; then the module needs no secret permissions.

## Inputs

`github_owner` and `name` are required. Everything else has a default: the
repository settings (visibility, features, merge buttons, sign-off), `labels`
(GitHub's stock set, managed authoritatively), `environments`, `allowed_actions`,
`ruleset`, and `required_secrets`. `manage_ruleset` and `actions_enabled` both
default to `true`. See [`variables.tf`](variables.tf) for the full input definitions.

## Default branch ruleset

Every repository gets the `main` ruleset by default. The `ruleset` variable holds
the provider-supported configuration captured from
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

The repository's merge buttons are separate inputs. `allow_rebase_merge = true`
enables the rebase button; the default repository settings enable squash merges.
The ruleset blocks merge commits on matching branches even when the repository
allows that button elsewhere.

Copy the `ruleset` default from `variables.tf` to customize the managed settings.
Its `rules` list supports the five captured rule types. Omitting a rule removes
that requirement. The existing inputs take precedence over the object:

| Input | Behavior |
| --- | --- |
| `manage_ruleset = false` | Omit the ruleset |
| `ruleset_enforcement` | Override enforcement; `null` uses the object |
| `ruleset_require_pull_request = false` | Omit the pull request rule |
| `ruleset_required_signatures` | Override the signature requirement; `null` uses the object |
| `ruleset_allowed_merge_methods` | Override the pull request merge methods; `null` uses the object |

For example, seeding a repository with existing history uses:

```hcl
ruleset_enforcement = "disabled"
```

Set it to `"active"` after pushing the history. `manage_ruleset = false` removes
an existing managed ruleset from GitHub on the next apply.

### Unmanaged review settings

`dismissal_restriction` and `require_extra_approval_for_unattributed_changes`
are omitted from the module's inputs because the
[GitHub provider schema](https://github.com/integrations/terraform-provider-github/blob/v6.13.0/github/resource_github_repository_ruleset.go)
does not expose them. Terraform neither configures them nor detects their drift.
GitHub determines their values when the request omits them; omission does not
mean disabling either setting.

The captured source ruleset has dismissal restrictions disabled and extra
approval for unattributed changes enabled. The API fixture records those values
as reference data; the module manages the remaining settings.

### Existing rulesets

Import a ruleset already on a repository before applying this module to it:

```sh
terraform import 'module.repo.github_repository_ruleset.main[0]' homebrew-tap:23733932
```

The repository itself must also be in the module's state. Adjust the module
address and repository name to match the caller.

## Outputs

`name`, `full_name`, `html_url`, `ssh_clone_url`, `http_clone_url`,
`owner_is_org`, `missing_secrets`.

## Requirements

- Terraform >= 1.10
- `integrations/github` ~> 6.13
- `hashicorp/http` ~> 3.0 (used to detect the owner type for the secret check)

See [`examples/complete`](examples/complete) for a runnable example.

## Related

CI that applies this module authenticates as a GitHub App created by the
[`github-app`](../github-app) module, which stores the `GH_APP_*` credentials a
workflow uses to mint the provider token.

## Dependency updates

Renovate keeps the Terraform and provider versions current. Its config
(`renovate.json`) extends the org-wide preset in
[`releasetools/.github`](https://github.com/releasetools/.github/blob/main/default.json),
so update policy lives in one place.

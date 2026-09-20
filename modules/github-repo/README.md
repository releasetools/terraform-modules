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
default to `true`. See [`variables.tf`](variables.tf) and [`ruleset.tf`](ruleset.tf) for the input definitions.

## Default branch ruleset

The [`ruleset` submodule](modules/ruleset) applies the default branch rules.
[`ruleset.tf`](ruleset.tf) wires it into this module and defines the forwarding
inputs. The submodule owns the typed configuration, defaults, and validation.

The default ruleset requires linear, signed history and pull requests with zero
approvals. It permits squash and rebase merges and blocks deletion and force
pushes. See the [submodule documentation](modules/ruleset/README.md) for the full
configuration and the two unmanaged review settings.

Set `ruleset` to an object matching the submodule's
[`variables.tf`](modules/ruleset/variables.tf) to customize the rules. `null`
uses the captured defaults. These inputs take precedence over that object:

| Input | Behavior |
| --- | --- |
| `manage_ruleset = false` | Omit the ruleset; destroy it on apply if already managed |
| `ruleset_enforcement` | Override enforcement; `null` uses the object |
| `ruleset_require_pull_request = false` | Omit the pull request rule |
| `ruleset_required_signatures` | Override the signature requirement; `null` uses the object |
| `ruleset_allowed_merge_methods` | Override the pull request merge methods; `null` uses the object |

The repository's merge buttons are separate inputs. `allow_rebase_merge = true`
enables the rebase button; the default repository settings enable squash merges.

### Existing rulesets

Terraform's `moved` blocks map either previous ruleset resource address to
`module.ruleset[0].github_repository_ruleset.main`, preserving the managed
ruleset during upgrades.

Import an existing ruleset that Terraform does not yet manage:

```sh
terraform import 'module.repo.module.ruleset[0].github_repository_ruleset.main' homebrew-tap:23733932
```

The repository itself must also be in this module's state. To manage only its
ruleset, call the [submodule directly](modules/ruleset/README.md#usage).

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

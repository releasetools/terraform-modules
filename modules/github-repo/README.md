# github-repo

A Terraform module that creates a GitHub repository and configures it (labels,
environments, Actions permissions, a branch ruleset) in one apply. It can also
confirm that the Actions secrets a repo's workflows need are present.

## Usage

```hcl
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 3.0"
    }
  }
}

variable "github_token" {
  type      = string
  sensitive = true
  ephemeral = true
}

provider "github" {
  owner = "your-org"
  token = var.github_token
}

provider "restapi" {
  uri                  = "https://api.github.com"
  bearer_token         = var.github_token
  write_returns_object = true
  headers = {
    Accept              = "application/vnd.github+json"
    X-GitHub-Api-Version = "2026-03-10"
  }
}

module "repo" {
  source = "git::https://github.com/releasetools/terraform-modules.git//modules/github-repo?ref=v0.3.0"

  github_owner = "your-org"
  name         = "my-service"
  description  = "What this repo is for."
  visibility   = "private"
}
```

You supply both providers and any backend. Both providers can use the same
GitHub App installation token. The token needs repository administration write
access to manage rulesets. Set `TF_VAR_github_token` in the environment; the
example marks it ephemeral so Terraform does not store it in plans or state.
The module has no provider or backend blocks of its own.

The example targets the pending `v0.3.0` release. Until it is tagged, use a local
checkout as the module source.

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
the configuration captured from
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

Copy the `ruleset` default from `variables.tf` to customize its full configuration.
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

### Complete API configuration

`restapi_object.main` manages the ruleset through GitHub's REST API. It sends
both `dismissal_restriction` and `require_extra_approval_for_unattributed_changes`
as part of the pull request parameters. Set these fields in `ruleset` to change
them. Dismissal actors use `{ id = 123, type = "Team" }` objects.

Terraform reads the ruleset on refresh and plans an update when a configured
field changes remotely. The resource ignores GitHub's response metadata, such
as timestamps and links. The REST provider uses POST to create, PUT to update,
and DELETE to remove the ruleset.

### Existing rulesets and state migration

Configure the REST provider, run `terraform init`, and import an existing
ruleset before applying this module to its repository:

```sh
terraform import 'module.repo.restapi_object.main[0]' /repos/releasetools/homebrew-tap/rulesets/23733932
terraform plan
```

The repository itself must also be in the module's state. Adjust the module
address and repository path to match the caller.

For an upgrade from an earlier module version, use the ID recorded in
`github_repository_ruleset.main[0]` (or `github_repository_ruleset.main` in
older state). The module's `removed` block forgets that old address without
deleting the GitHub ruleset. Importing the same ID at the REST address keeps
that ruleset under Terraform management. Check that the plan forgets the old
address and updates the imported resource. A proposed REST resource creation
means the import is missing; complete it before applying.

## Validation

Run from this module directory:

```sh
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test
python3 tests/restapi_lifecycle.py
```

The lifecycle test uses the installed REST provider and a local HTTP server.
It checks full payload writes, drift repair for both review fields, importing an
existing ruleset, and deletion. It does not contact GitHub.

## Outputs

`name`, `full_name`, `html_url`, `ssh_clone_url`, `http_clone_url`,
`owner_is_org`, `missing_secrets`.

## Requirements

- Terraform >= 1.10
- `integrations/github` ~> 6.0
- `Mastercard/restapi` ~> 3.0
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

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
  source = "git::https://github.com/releasetools/terraform-modules.git//modules/github-repo?ref=v0.1.0"

  github_owner = "your-org"
  name         = "my-service"
  description  = "What this repo is for."
  visibility   = "private"
}
```

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
`ruleset_enforcement`, and `required_secrets`. The ruleset and Actions are
toggleable: `manage_ruleset`, `ruleset_require_pull_request`,
`ruleset_required_signatures`, and `actions_enabled` (all default to the secure
behavior). See `variables.tf`.

## Outputs

`name`, `full_name`, `html_url`, `ssh_clone_url`, `http_clone_url`,
`owner_is_org`, `missing_secrets`.

## Requirements

- Terraform >= 1.10
- `integrations/github` ~> 6.0
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

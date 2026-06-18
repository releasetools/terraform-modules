# github-app

Tooling for a shared GitHub App that automates repositories. Create the App from
a manifest, store its credentials, and pin which repos its installation can
reach.

GitHub has no API to create an App, so creation is a one-click manifest flow
(`scripts/create-github-app.sh`). The Terraform here manages the installation's
repository access afterward.

## Create the App

```sh
scripts/create-github-app.sh
```

It asks where the App should live (an organization or your account), runs the
manifest flow in your browser (one click), then stores the credentials. For an
org it sets, on that org:

- `GH_APP_CLIENT_ID` and `GH_APP_ID` (variables), `GH_APP_PRIVATE_KEY` (secret).

A workflow mints a token from these with `actions/create-github-app-token`. The
App's permissions live in `manifest.json`: Actions, Administration, Issues, and
Environments write; Contents, Metadata, and Secrets read; plus org Secrets read.
(Managing deployment environments needs Actions, not just Administration —
GitHub gates the environments API behind the Actions permission.)

Overrides (skip the prompt): `OWNER=<org>` (or your login for a personal app),
`PORT`, `VISIBILITY`, `MANIFEST`.

## Pin installation access

Install the App on your repos (the script prints the link). Find the installation
id (needs `admin:org`):

```sh
gh api /orgs/<org>/installations \
  --jq '.installations[] | select(.app_slug=="<app-slug>") | .id'
```

Then pin which repos the installation can reach, as code:

```hcl
provider "github" {
  owner = "your-org"
}

module "app_install" {
  source = "git::https://github.com/releasetools/terraform-modules.git//modules/github-app?ref=v0.1.0"

  app_slug        = "your-app-slug"
  installation_id = "12345678"
  repositories    = ["repo-a", "repo-b"]
}
```

The association is additive, so it never detaches repos that other projects share
on the same App. See [`examples/install`](examples/install) for a runnable root.

One caveat: this resource hits the user-context endpoint `PUT
/user/installations/{id}/repositories/{repo_id}`, so it needs a token from a user
who owns the org (a PAT with `admin:org`). An App token can't modify its own
installation, so this won't run in App-authenticated CI. If that's your setup,
install the App with "Only select repositories" and manage the list in the GitHub
UI instead.

## Related

This App authenticates CI for the [`github-repo`](../github-repo) module, the
companion that creates and configures a repository. The `GH_APP_*` credentials
this script stores are what a workflow uses to mint the github provider token
there.

## Requirements

- Terraform >= 1.15, `integrations/github` ~> 6.12
- `gh`, `jq`, and `python3` for the create script

## Dependency updates

Renovate keeps the Terraform and provider versions current. Its config
(`renovate.json`) extends the org-wide preset in
[`releasetools/.github`](https://github.com/releasetools/.github/blob/main/default.json),
so update policy lives in one place.

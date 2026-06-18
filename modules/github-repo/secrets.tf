# Confirm the required Actions secrets EXIST (by name) — never reads values.
# Opt-in: only runs when required_secrets is non-empty. It then needs
# Secrets: read (and, for an org owner, Organization secrets: read), not admin.

locals {
  check_secrets = length(var.required_secrets) > 0
  owner_is_org  = local.check_secrets ? jsondecode(data.http.owner[0].response_body).type == "Organization" : false

  repo_secret_names = local.check_secrets ? toset([for s in data.github_actions_secrets.repo[0].secrets : s.name]) : toset([])

  # Org secrets that reach this repo: visibility "all" (every repo) or "private"
  # (every private repo). "selected" visibility isn't resolved here.
  org_secret_names = local.owner_is_org ? toset([
    for s in data.github_actions_organization_secrets.org[0].secrets :
    s.name if contains(["all", "private"], s.visibility)
  ]) : toset([])

  available_secrets = setunion(local.repo_secret_names, local.org_secret_names)
  missing_secrets   = setsubtract(toset(var.required_secrets), local.available_secrets)
}

# Owner type, auto-detected. GET /users/{owner} works for both and returns
# "type", so the org-secret lookup runs only for an org. Unauthenticated public
# metadata; only read when the secret check is on.
data "http" "owner" {
  count = local.check_secrets ? 1 : 0
  url   = "https://api.github.com/users/${var.github_owner}"
  request_headers = {
    Accept = "application/vnd.github+json"
  }
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "GitHub owner lookup failed (HTTP ${self.status_code}) for '${var.github_owner}'."
    }
  }
}

# Repo-level Actions secrets (names only). depends_on the repo so a single apply
# can create the repo AND check its secrets: the read defers to apply time.
data "github_actions_secrets" "repo" {
  count      = local.check_secrets ? 1 : 0
  name       = var.name
  depends_on = [github_repository.this]
}

# Org-level Actions secrets — only for an org owner.
data "github_actions_organization_secrets" "org" {
  count = local.owner_is_org ? 1 : 0
}

check "required_actions_secrets" {
  assert {
    condition = length(local.missing_secrets) == 0
    error_message = format(
      "Missing Actions secret(s): %s. Create them on the repo (or have the org provide them).",
      join(", ", local.missing_secrets),
    )
  }
}

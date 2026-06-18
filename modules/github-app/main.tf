# Read the App (to surface its ids). The App itself is created from
# manifest.json via the manifest flow (scripts/create-github-app.sh) — Terraform
# can't create a GitHub App.
data "github_app" "this" {
  slug = var.app_slug
}

# Ensure the App installation can access each repository. Additive: it adds the
# association without removing other repos from the installation.
resource "github_app_installation_repository" "this" {
  for_each = toset(var.repositories)

  installation_id = var.installation_id
  repository      = each.value
}

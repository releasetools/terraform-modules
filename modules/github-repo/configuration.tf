# Repository references order these resources after repository creation.

# Labels reconcile the full set, including GitHub defaults.
resource "github_issue_labels" "this" {
  repository = github_repository.this.name

  dynamic "label" {
    for_each = var.labels
    content {
      name        = label.value.name
      color       = label.value.color
      description = label.value.description
    }
  }
}

# Deployment environments (no protection rules).
resource "github_repository_environment" "this" {
  for_each    = toset(var.environments)
  repository  = github_repository.this.name
  environment = each.value
}

# Actions runtime policy.
resource "github_actions_repository_permissions" "this" {
  repository      = github_repository.this.name
  enabled         = var.actions_enabled
  allowed_actions = var.allowed_actions
}

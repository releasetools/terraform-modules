# Everything below references the repository RESOURCE (github_repository.this),
# so it's created after the repo in the same apply — no separate stage needed.

# Labels — managed authoritatively (reconciles the auto-created defaults).
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

locals {
  ruleset_rules = concat(
    [for rule in var.ruleset.rules : merge(
      { type = rule.type },
      rule.type == "pull_request" ? {
        parameters = merge(rule.parameters, {
          allowed_merge_methods = coalesce(var.ruleset_allowed_merge_methods, rule.parameters.allowed_merge_methods)
        })
      } : {}
      ) if(
      (rule.type != "pull_request" || var.ruleset_require_pull_request) &&
      (rule.type != "required_signatures" || var.ruleset_required_signatures != false)
    )],
    var.ruleset_required_signatures == true && !contains([for rule in var.ruleset.rules : rule.type], "required_signatures") ? [{ type = "required_signatures" }] : []
  )
}

resource "restapi_object" "main" {
  count = var.manage_ruleset ? 1 : 0
  path  = "/repos/${var.github_owner}/${github_repository.this.name}/rulesets"
  data = jsonencode(merge(var.ruleset, {
    enforcement = coalesce(var.ruleset_enforcement, var.ruleset.enforcement)
    rules       = local.ruleset_rules
  }))

  # GitHub returns this metadata alongside the writable ruleset configuration.
  ignore_changes_to = [
    "id", "node_id", "source", "source_type", "created_at", "updated_at",
    "current_user_can_bypass", "_links",
  ]
}

# Import existing rulesets at restapi_object.main[0] before applying this module.
# Forgetting the old address must not delete the ruleset from GitHub.
removed {
  from = github_repository_ruleset.main

  lifecycle {
    destroy = false
  }
}

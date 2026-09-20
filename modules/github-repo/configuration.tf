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
  ruleset_rules = { for rule in var.ruleset.rules : rule.type => rule.parameters }
}

resource "github_repository_ruleset" "main" {
  count       = var.manage_ruleset ? 1 : 0
  name        = var.ruleset.name
  repository  = github_repository.this.name
  target      = var.ruleset.target
  enforcement = coalesce(var.ruleset_enforcement, var.ruleset.enforcement)

  conditions {
    ref_name {
      include = var.ruleset.conditions.ref_name.include
      exclude = var.ruleset.conditions.ref_name.exclude
    }
  }

  dynamic "bypass_actors" {
    for_each = var.ruleset.bypass_actors
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  rules {
    deletion                = contains(keys(local.ruleset_rules), "deletion")
    non_fast_forward        = contains(keys(local.ruleset_rules), "non_fast_forward")
    required_linear_history = contains(keys(local.ruleset_rules), "required_linear_history")
    required_signatures     = coalesce(var.ruleset_required_signatures, contains(keys(local.ruleset_rules), "required_signatures"))

    dynamic "pull_request" {
      for_each = var.ruleset_require_pull_request ? { for type, parameters in local.ruleset_rules : type => parameters if type == "pull_request" } : {}
      content {
        required_approving_review_count   = pull_request.value.required_approving_review_count
        dismiss_stale_reviews_on_push     = pull_request.value.dismiss_stale_reviews_on_push
        require_code_owner_review         = pull_request.value.require_code_owner_review
        require_last_push_approval        = pull_request.value.require_last_push_approval
        required_review_thread_resolution = pull_request.value.required_review_thread_resolution
        allowed_merge_methods             = coalesce(var.ruleset_allowed_merge_methods, pull_request.value.allowed_merge_methods)

        dynamic "required_reviewers" {
          for_each = pull_request.value.required_reviewers
          content {
            reviewer {
              id   = required_reviewers.value.reviewer.id
              type = required_reviewers.value.reviewer.type
            }
            file_patterns     = required_reviewers.value.file_patterns
            minimum_approvals = required_reviewers.value.minimum_approvals
          }
        }
      }
    }
  }
}

# The ruleset gained a `count` in v0.2.0; keep existing state from recreating it.
moved {
  from = github_repository_ruleset.main
  to   = github_repository_ruleset.main[0]
}

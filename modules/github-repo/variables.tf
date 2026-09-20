variable "github_owner" {
  type        = string
  description = "GitHub org/user that owns the repo (used to auto-detect org vs user for the secret check)."
}

variable "name" {
  type        = string
  description = "Repository name."
}

variable "description" {
  type    = string
  default = null
}

variable "homepage_url" {
  type    = string
  default = null
}

variable "visibility" {
  type    = string
  default = "private"

  validation {
    condition     = contains(["private", "public", "internal"], var.visibility)
    error_message = "visibility must be one of: private, public, internal."
  }
}

variable "topics" {
  type    = list(string)
  default = []
}

# Features
variable "has_issues" {
  type    = bool
  default = true
}
variable "has_projects" {
  type    = bool
  default = false
}
variable "has_wiki" {
  type    = bool
  default = false
}
variable "has_discussions" {
  type    = bool
  default = false
}
variable "is_template" {
  type    = bool
  default = false
}

# Merge buttons and commit-message templates
variable "allow_merge_commit" {
  type    = bool
  default = true
}
variable "allow_squash_merge" {
  type    = bool
  default = true
}
variable "allow_rebase_merge" {
  type    = bool
  default = false
}
variable "allow_auto_merge" {
  type    = bool
  default = false
}
variable "allow_update_branch" {
  type    = bool
  default = false
}
variable "delete_branch_on_merge" {
  type    = bool
  default = true
}
variable "squash_merge_commit_title" {
  type    = string
  default = "PR_TITLE"
}
variable "squash_merge_commit_message" {
  type    = string
  default = "COMMIT_MESSAGES"
}
variable "merge_commit_title" {
  type    = string
  default = "PR_TITLE"
}
variable "merge_commit_message" {
  type    = string
  default = "BLANK"
}

variable "web_commit_signoff_required" {
  type    = bool
  default = true
}

variable "auto_init" {
  type        = bool
  default     = false
  description = "Create the repo with an initial commit. Leave false to push existing history."
}

variable "archive_on_destroy" {
  type    = bool
  default = true
}

variable "manage_default_branch" {
  type        = bool
  default     = false
  description = "Set the default branch (requires it to exist; the first pushed branch is default on its own)."
}

variable "default_branch" {
  type    = string
  default = "main"
}

variable "labels" {
  type = list(object({
    name        = string
    color       = string
    description = optional(string, "")
  }))
  default = [
    { name = "bug", color = "d73a4a", description = "Something isn't working" },
    { name = "documentation", color = "0075ca", description = "Improvements or additions to documentation" },
    { name = "duplicate", color = "cfd3d7", description = "This issue or pull request already exists" },
    { name = "enhancement", color = "a2eeef", description = "New feature or request" },
    { name = "good first issue", color = "7057ff", description = "Good for newcomers" },
    { name = "help wanted", color = "008672", description = "Extra attention is needed" },
    { name = "invalid", color = "e4e669", description = "This doesn't seem right" },
    { name = "question", color = "d876e3", description = "Further information is requested" },
    { name = "wontfix", color = "ffffff", description = "This will not be worked on" },
  ]
  description = <<-EOT
    The full label set, managed authoritatively (github_issue_labels reconciles
    the whole set). Defaults to GitHub's stock labels so it doesn't delete the
    auto-created ones; override to add or replace.
  EOT
}

variable "environments" {
  type        = list(string)
  default     = []
  description = "Deployment environments to create (no protection rules)."
}

variable "allowed_actions" {
  type    = string
  default = "all"
}

variable "required_secrets" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Names of Actions secrets a workflow needs. When set, the module confirms they
    exist (by name) at the repo or org level and warns about any missing — it
    never creates them and never reads their values. Empty (the default) skips
    the check entirely (and needs no Secrets:read permission).
  EOT
}

variable "ruleset" {
  description = <<-EOT
    Default-branch ruleset in GitHub's API shape, captured from
    releasetools/homebrew-tap ruleset 23733932. Supports its five rule types.
    The provider cannot manage dismissal_restriction or
    require_extra_approval_for_unattributed_changes; their captured values
    are fixed by validation. See the README for that limitation.
  EOT
  type = object({
    name        = string
    target      = string
    enforcement = string
    conditions = object({
      ref_name = object({
        include = list(string)
        exclude = list(string)
      })
    })
    bypass_actors = list(object({
      actor_id    = optional(number)
      actor_type  = string
      bypass_mode = string
    }))
    rules = list(object({
      type = string
      parameters = optional(object({
        required_approving_review_count = number
        dismiss_stale_reviews_on_push   = bool
        required_reviewers = list(object({
          reviewer = object({
            id   = number
            type = string
          })
          file_patterns     = list(string)
          minimum_approvals = number
        }))
        require_code_owner_review = bool
        dismissal_restriction = object({
          enabled = bool
          allowed_actors = list(object({
            actor_id   = number
            actor_type = string
          }))
        })
        require_last_push_approval                      = bool
        required_review_thread_resolution               = bool
        require_extra_approval_for_unattributed_changes = bool
        allowed_merge_methods                           = list(string)
      }))
    }))
  })
  nullable = false
  default = {
    name        = "main"
    target      = "branch"
    enforcement = "active"
    conditions = {
      ref_name = {
        exclude = []
        include = ["~DEFAULT_BRANCH"]
      }
    }
    bypass_actors = []
    rules = [
      { type = "deletion" },
      { type = "non_fast_forward" },
      { type = "required_linear_history" },
      { type = "required_signatures" },
      {
        type = "pull_request"
        parameters = {
          required_approving_review_count = 0
          dismiss_stale_reviews_on_push   = false
          required_reviewers              = []
          require_code_owner_review       = false
          dismissal_restriction = {
            enabled        = false
            allowed_actors = []
          }
          require_last_push_approval                      = false
          required_review_thread_resolution               = false
          require_extra_approval_for_unattributed_changes = true
          allowed_merge_methods                           = ["squash", "rebase"]
        }
      },
    ]
  }

  validation {
    condition     = var.ruleset.target == "branch" && contains(["active", "disabled", "evaluate"], var.ruleset.enforcement)
    error_message = "ruleset must target branches with active, disabled, or evaluate enforcement."
  }

  validation {
    condition = (
      length(distinct([for rule in var.ruleset.rules : rule.type])) == length(var.ruleset.rules) &&
      alltrue([for rule in var.ruleset.rules :
        contains(["deletion", "non_fast_forward", "required_linear_history", "required_signatures", "pull_request"], rule.type) &&
        (rule.type == "pull_request" ? rule.parameters != null : rule.parameters == null)
      ])
    )
    error_message = "ruleset rules must use each supported type at most once; only pull_request requires parameters."
  }

  validation {
    condition = alltrue([for rule in var.ruleset.rules : rule.parameters == null ? true : (
      !rule.parameters.dismissal_restriction.enabled &&
      length(rule.parameters.dismissal_restriction.allowed_actors) == 0 &&
      rule.parameters.require_extra_approval_for_unattributed_changes
    )])
    error_message = "The GitHub provider cannot manage dismissal_restriction or require_extra_approval_for_unattributed_changes. Keep their captured values: disabled, no actors, and true."
  }
}

variable "ruleset_enforcement" {
  type        = string
  default     = null
  description = "Override ruleset.enforcement; null uses the ruleset value (active by default). Use disabled to seed existing history."

  validation {
    condition     = var.ruleset_enforcement == null ? true : contains(["active", "disabled"], var.ruleset_enforcement)
    error_message = "ruleset_enforcement must be active or disabled."
  }
}

variable "ruleset_allowed_merge_methods" {
  type        = list(string)
  default     = null
  description = "Override the pull request rule's allowed_merge_methods; null uses the ruleset value (squash and rebase by default)."
}

variable "manage_ruleset" {
  type        = bool
  default     = true
  description = "Manage the default-branch ruleset. Set false to skip it entirely (e.g. a bot-only mirror that needs no branch rules)."
}

variable "ruleset_require_pull_request" {
  type        = bool
  default     = true
  description = "Apply the pull request rule in ruleset. Set false to omit it."
}

variable "ruleset_required_signatures" {
  type        = bool
  default     = null
  description = "Override the required_signatures rule; null uses the ruleset value (required by default)."
}

variable "actions_enabled" {
  type        = bool
  default     = true
  description = "Enable GitHub Actions on the repo. Set false for a repo that runs no workflows."
}

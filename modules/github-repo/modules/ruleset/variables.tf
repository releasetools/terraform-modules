variable "repository" {
  type        = string
  description = "Name of the existing repository in the GitHub provider owner account."
}

variable "ruleset" {
  description = <<-EOT
    Default-branch ruleset in GitHub's API shape, captured from
    releasetools/homebrew-tap ruleset 23733932. Supports its five rule types.
    Includes the provider-supported settings. The two unsupported review
    fields are omitted and remain outside Terraform's control; see the README.
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
        require_code_owner_review         = bool
        require_last_push_approval        = bool
        required_review_thread_resolution = bool
        allowed_merge_methods             = list(string)
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
          required_approving_review_count   = 0
          dismiss_stale_reviews_on_push     = false
          required_reviewers                = []
          require_code_owner_review         = false
          require_last_push_approval        = false
          required_review_thread_resolution = false
          allowed_merge_methods             = ["squash", "rebase"]
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

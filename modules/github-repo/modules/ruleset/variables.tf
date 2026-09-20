variable "repository" {
  type        = string
  description = "Name of the existing repository in the GitHub provider owner account."
}

variable "ruleset" {
  description = <<-EOT
    Branch ruleset in GitHub's API shape, including required status checks.
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
        required_approving_review_count = optional(number, 0)
        dismiss_stale_reviews_on_push   = optional(bool, false)
        required_reviewers = optional(list(object({
          reviewer = object({
            id   = number
            type = string
          })
          file_patterns     = list(string)
          minimum_approvals = number
        })), [])
        require_code_owner_review            = optional(bool, false)
        require_last_push_approval           = optional(bool, false)
        required_review_thread_resolution    = optional(bool, false)
        allowed_merge_methods                = optional(list(string), ["squash", "rebase"])
        strict_required_status_checks_policy = optional(bool, false)
        do_not_enforce_on_create             = optional(bool, false)
        required_status_checks = optional(list(object({
          context        = string
          integration_id = optional(number)
        })), [])
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
        contains(["deletion", "non_fast_forward", "required_linear_history", "required_signatures", "pull_request", "required_status_checks"], rule.type) &&
        (contains(["pull_request", "required_status_checks"], rule.type) ? rule.parameters != null : rule.parameters == null)
      ])
    )
    error_message = "ruleset rules must use each supported type at most once; pull_request and required_status_checks require parameters, while other rules omit them."
  }

  validation {
    condition = alltrue([for rule in var.ruleset.rules :
      rule.type == "required_status_checks" ? try(
        length(rule.parameters.required_status_checks) > 0 &&
        alltrue([for check in rule.parameters.required_status_checks : trimspace(check.context) != ""]),
        false
      ) : true
    ])
    error_message = "required_status_checks requires at least one check with a nonempty context."
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

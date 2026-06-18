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

variable "ruleset_enforcement" {
  type        = string
  default     = "active"
  description = "Default-branch ruleset enforcement: active or disabled (disabled to seed existing history)."

  validation {
    condition     = contains(["active", "disabled"], var.ruleset_enforcement)
    error_message = "ruleset_enforcement must be active or disabled."
  }
}

variable "ruleset_allowed_merge_methods" {
  type    = list(string)
  default = ["squash", "merge"]
}

variable "manage_ruleset" {
  type        = bool
  default     = true
  description = "Manage the default-branch ruleset. Set false to skip it entirely (e.g. a bot-only mirror that needs no branch rules)."
}

variable "ruleset_require_pull_request" {
  type        = bool
  default     = true
  description = "Require a pull request (0 approvals) to update the default branch. Set false to drop the PR rule, e.g. a fast-forward-only mirror."
}

variable "ruleset_required_signatures" {
  type        = bool
  default     = true
  description = "Require signed commits on the default branch. Set false where commits are unsigned, e.g. a filtered mirror."
}

variable "actions_enabled" {
  type        = bool
  default     = true
  description = "Enable GitHub Actions on the repo. Set false for a repo that runs no workflows."
}

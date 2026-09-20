module "ruleset" {
  source = "./modules/ruleset"
  count  = var.manage_ruleset ? 1 : 0

  repository                    = github_repository.this.name
  ruleset                       = var.ruleset
  ruleset_enforcement           = var.ruleset_enforcement
  ruleset_allowed_merge_methods = var.ruleset_allowed_merge_methods
  ruleset_require_pull_request  = var.ruleset_require_pull_request
  ruleset_required_signatures   = var.ruleset_required_signatures
}

# Preserve state from both previously supported resource addresses.
moved {
  from = github_repository_ruleset.main
  to   = github_repository_ruleset.main[0]
}

moved {
  from = github_repository_ruleset.main[0]
  to   = module.ruleset[0].github_repository_ruleset.main
}

variable "ruleset" {
  type        = any
  default     = null
  description = "Ruleset configuration validated by modules/ruleset. Null uses the submodule's defaults."
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

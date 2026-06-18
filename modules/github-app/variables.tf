variable "app_slug" {
  type        = string
  description = "The GitHub App's slug, from its settings URL."
}

variable "installation_id" {
  type        = string
  description = "The App's installation id on the owner (gh api /orgs/<org>/installations)."
}

variable "repositories" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Repositories the App installation must be able to access. Managed additively
    (one association each), so this never removes other repos already attached to
    the installation — safe for an App shared across repos.
  EOT
}

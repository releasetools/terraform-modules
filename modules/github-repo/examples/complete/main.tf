terraform {
  required_version = ">= 1.10.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

variable "owner" {
  type        = string
  description = "GitHub org or user to create the example repo under."
}

provider "github" {
  owner = var.owner
}

module "repo" {
  source = "../../"

  github_owner = var.owner
  name         = "example-repo"
  description  = "Created by the terraform-github-repo complete example."
  visibility   = "private"
  topics       = ["example"]

  # Seed history first by applying with this set to "disabled", then "active".
  ruleset_enforcement = "active"

  # Opt into the secret check (needs Secrets: read on the token):
  # required_secrets = ["DEPLOY_KEY"]
}

output "repository" {
  value = module.repo.full_name
}

output "missing_secrets" {
  value = module.repo.missing_secrets
}

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 3.0"
    }
  }
}

variable "owner" {
  type        = string
  description = "GitHub org or user to create the example repo under."
}

variable "github_token" {
  type        = string
  sensitive   = true
  ephemeral   = true
  description = "GitHub token used by both providers, such as an App installation token."
}

provider "github" {
  owner = var.owner
  token = var.github_token
}

provider "restapi" {
  uri                  = "https://api.github.com"
  bearer_token         = var.github_token
  write_returns_object = true
  headers = {
    Accept               = "application/vnd.github+json"
    X-GitHub-Api-Version = "2026-03-10"
  }
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

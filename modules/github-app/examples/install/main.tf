terraform {
  required_version = ">= 1.15.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.12"
    }
  }
}

variable "owner" {
  type        = string
  description = "GitHub org or user the App is installed under."
}

variable "app_slug" {
  type = string
}

variable "installation_id" {
  type        = string
  description = "gh api /orgs/<owner>/installations --jq '.installations[]|select(.app_slug==\"<slug>\").id'"
}

variable "repositories" {
  type    = list(string)
  default = []
}

provider "github" {
  owner = var.owner
}

module "app_install" {
  source = "../../"

  app_slug        = var.app_slug
  installation_id = var.installation_id
  repositories    = var.repositories
}

output "app_id" {
  value = module.app_install.app_id
}

# Reusable module — no provider or backend blocks (those belong to the caller).
terraform {
  required_version = ">= 1.15.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.12"
    }
  }
}

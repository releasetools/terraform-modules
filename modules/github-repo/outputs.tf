output "name" {
  value       = github_repository.this.name
  description = "Repository name."
}

output "full_name" {
  value       = github_repository.this.full_name
  description = "owner/name."
}

output "html_url" {
  value = github_repository.this.html_url
}

output "ssh_clone_url" {
  value       = github_repository.this.ssh_clone_url
  description = "Use as the remote to push history."
}

output "http_clone_url" {
  value = github_repository.this.http_clone_url
}

output "owner_is_org" {
  value       = local.owner_is_org
  description = "Whether the owner was detected as an organization."
}

output "missing_secrets" {
  value       = local.missing_secrets
  description = "Required Actions secrets not yet defined at the repo or org level."
}

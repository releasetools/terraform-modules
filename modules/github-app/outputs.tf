output "app_id" {
  value       = data.github_app.this.id
  description = "Numeric App id."
}

output "app_slug" {
  value       = data.github_app.this.slug
  description = "App slug."
}

output "app_node_id" {
  value       = data.github_app.this.node_id
  description = "App node id (GraphQL)."
}

output "repositories" {
  value       = [for r in github_app_installation_repository.this : r.repository]
  description = "Repositories attached to the installation by this module."
}

resource "github_repository" "this" {
  name         = var.name
  description  = var.description
  homepage_url = var.homepage_url
  visibility   = var.visibility

  has_issues      = var.has_issues
  has_projects    = var.has_projects
  has_wiki        = var.has_wiki
  has_discussions = var.has_discussions
  is_template     = var.is_template

  allow_merge_commit     = var.allow_merge_commit
  allow_squash_merge     = var.allow_squash_merge
  allow_rebase_merge     = var.allow_rebase_merge
  allow_auto_merge       = var.allow_auto_merge
  allow_update_branch    = var.allow_update_branch
  delete_branch_on_merge = var.delete_branch_on_merge

  squash_merge_commit_title   = var.squash_merge_commit_title
  squash_merge_commit_message = var.squash_merge_commit_message
  merge_commit_title          = var.merge_commit_title
  merge_commit_message        = var.merge_commit_message

  web_commit_signoff_required = var.web_commit_signoff_required

  topics = var.topics

  auto_init          = var.auto_init
  archive_on_destroy = var.archive_on_destroy
}

resource "github_branch_default" "this" {
  count      = var.manage_default_branch ? 1 : 0
  repository = github_repository.this.name
  branch     = var.default_branch
}

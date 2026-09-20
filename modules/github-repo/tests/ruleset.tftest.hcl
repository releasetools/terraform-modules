mock_provider "github" {}
mock_provider "http" {}

variables {
  github_owner = "example"
  name         = "example"
}

run "captured_defaults" {
  command = plan

  assert {
    condition = jsonencode(var.ruleset) == jsonencode(merge(
      jsondecode(file("tests/fixtures/main-ruleset.json")),
      { rules = [for rule in jsondecode(file("tests/fixtures/main-ruleset.json")).rules : merge({ parameters = null }, rule)] }
    ))
    error_message = "The default must capture the GitHub API configuration, including fields the provider cannot manage."
  }

  assert {
    condition = (
      length(github_repository_ruleset.main) == 1 &&
      github_repository_ruleset.main[0].name == "main" &&
      github_repository_ruleset.main[0].target == "branch" &&
      github_repository_ruleset.main[0].enforcement == "active" &&
      github_repository_ruleset.main[0].conditions[0].ref_name[0].include == tolist(["~DEFAULT_BRANCH"]) &&
      length(github_repository_ruleset.main[0].conditions[0].ref_name[0].exclude) == 0 &&
      length(github_repository_ruleset.main[0].bypass_actors) == 0
    )
    error_message = "Every repository must get the active default-branch ruleset without bypass actors."
  }

  assert {
    condition = (
      github_repository_ruleset.main[0].rules[0].deletion &&
      github_repository_ruleset.main[0].rules[0].non_fast_forward &&
      github_repository_ruleset.main[0].rules[0].required_linear_history &&
      github_repository_ruleset.main[0].rules[0].required_signatures
    )
    error_message = "The default branch must block deletion and force pushes and require linear, signed history."
  }

  assert {
    condition = jsonencode(github_repository_ruleset.main[0].rules[0].pull_request[0]) == jsonencode({
      for key, value in jsondecode(file("tests/fixtures/main-ruleset.json")).rules[4].parameters : key => value
      if !contains(["dismissal_restriction", "require_extra_approval_for_unattributed_changes"], key)
    })
    error_message = "Every provider-supported pull request parameter must match the captured ruleset."
  }
}

run "legacy_overrides" {
  command = plan

  variables {
    ruleset_enforcement           = "disabled"
    ruleset_required_signatures   = false
    ruleset_allowed_merge_methods = ["squash"]
  }

  assert {
    condition = (
      github_repository_ruleset.main[0].enforcement == "disabled" &&
      !github_repository_ruleset.main[0].rules[0].required_signatures &&
      github_repository_ruleset.main[0].rules[0].pull_request[0].allowed_merge_methods == tolist(["squash"])
    )
    error_message = "Existing inputs must override the captured defaults."
  }
}

run "omit_pull_request" {
  command = plan

  variables {
    ruleset_require_pull_request = false
  }

  assert {
    condition = (
      length(github_repository_ruleset.main[0].rules[0].pull_request) == 0 &&
      github_repository_ruleset.main[0].rules[0].required_signatures &&
      github_repository_ruleset.main[0].rules[0].required_linear_history
    )
    error_message = "Disabling pull requests must preserve the other requirements."
  }
}

run "omit_ruleset" {
  command = plan

  variables {
    manage_ruleset = false
  }

  assert {
    condition     = length(github_repository_ruleset.main) == 0
    error_message = "manage_ruleset=false must omit the ruleset."
  }
}

run "custom_configuration" {
  command = plan

  variables {
    ruleset = merge(jsondecode(file("tests/fixtures/main-ruleset.json")), {
      name        = "release"
      enforcement = "disabled"
      conditions = {
        ref_name = { include = ["refs/heads/release/*"], exclude = ["refs/heads/release/test"] }
      }
      bypass_actors = [{ actor_id = 123, actor_type = "Integration", bypass_mode = "pull_request" }]
      rules = [{
        type = "pull_request"
        parameters = merge(jsondecode(file("tests/fixtures/main-ruleset.json")).rules[4].parameters, {
          required_approving_review_count   = 2
          dismiss_stale_reviews_on_push     = true
          require_code_owner_review         = true
          require_last_push_approval        = true
          required_review_thread_resolution = true
          allowed_merge_methods             = ["squash"]
          required_reviewers = [{
            reviewer          = { id = 456, type = "Team" }
            file_patterns     = ["*.tf"]
            minimum_approvals = 1
          }]
        })
      }]
    })
  }

  assert {
    condition = (
      github_repository_ruleset.main[0].name == "release" &&
      github_repository_ruleset.main[0].enforcement == "disabled" &&
      github_repository_ruleset.main[0].conditions[0].ref_name[0].include == tolist(["refs/heads/release/*"]) &&
      github_repository_ruleset.main[0].conditions[0].ref_name[0].exclude == tolist(["refs/heads/release/test"]) &&
      github_repository_ruleset.main[0].bypass_actors[0].actor_id == 123 &&
      github_repository_ruleset.main[0].bypass_actors[0].actor_type == "Integration" &&
      github_repository_ruleset.main[0].bypass_actors[0].bypass_mode == "pull_request"
    )
    error_message = "Custom ruleset identity, conditions, and bypass actors must reach the resource."
  }

  assert {
    condition = (
      !github_repository_ruleset.main[0].rules[0].deletion &&
      !github_repository_ruleset.main[0].rules[0].non_fast_forward &&
      !github_repository_ruleset.main[0].rules[0].required_linear_history &&
      !github_repository_ruleset.main[0].rules[0].required_signatures
    )
    error_message = "Rules omitted from the object must not be enabled."
  }

  assert {
    condition = jsonencode(github_repository_ruleset.main[0].rules[0].pull_request[0]) == jsonencode(merge(
      { for key, value in var.ruleset.rules[0].parameters : key => value
        if !contains(["dismissal_restriction", "require_extra_approval_for_unattributed_changes", "required_reviewers"], key)
      },
      { required_reviewers = [for reviewer in var.ruleset.rules[0].parameters.required_reviewers : merge(reviewer, { reviewer = [reviewer.reviewer] })] }
    ))
    error_message = "Custom review settings, merge methods, and team reviewers must reach the resource."
  }
}

run "reject_unsupported_review_override" {
  command = plan

  variables {
    ruleset = merge(jsondecode(file("tests/fixtures/main-ruleset.json")), {
      rules = [{
        type = "pull_request"
        parameters = merge(jsondecode(file("tests/fixtures/main-ruleset.json")).rules[4].parameters, {
          require_extra_approval_for_unattributed_changes = false
        })
      }]
    })
  }

  expect_failures = [var.ruleset]
}

run "reject_unsupported_dismissal_override" {
  command = plan

  variables {
    ruleset = merge(jsondecode(file("tests/fixtures/main-ruleset.json")), {
      rules = [{
        type = "pull_request"
        parameters = merge(jsondecode(file("tests/fixtures/main-ruleset.json")).rules[4].parameters, {
          dismissal_restriction = { enabled = true, allowed_actors = [] }
        })
      }]
    })
  }

  expect_failures = [var.ruleset]
}

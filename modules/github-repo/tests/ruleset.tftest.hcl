mock_provider "github" {}
mock_provider "http" {}
mock_provider "restapi" {}

variables {
  github_owner = "example"
  name         = "example"
}

run "captured_defaults" {
  command = plan

  assert {
    condition     = restapi_object.main[0].data == jsonencode(jsondecode(file("tests/fixtures/main-ruleset.json")))
    error_message = "The API payload must match the complete captured configuration, including both review fields."
  }

  assert {
    condition     = restapi_object.main[0].path == "/repos/example/example/rulesets"
    error_message = "The ruleset must belong to the module's repository."
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
      jsondecode(restapi_object.main[0].data).enforcement == "disabled" &&
      !contains([for rule in jsondecode(restapi_object.main[0].data).rules : rule.type], "required_signatures") &&
      one([for rule in jsondecode(restapi_object.main[0].data).rules : rule.parameters.allowed_merge_methods if rule.type == "pull_request"]) == ["squash"]
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
    condition = toset([for rule in jsondecode(restapi_object.main[0].data).rules : rule.type]) == toset([
      "deletion", "non_fast_forward", "required_linear_history", "required_signatures",
    ])
    error_message = "Disabling pull requests must preserve the other requirements."
  }
}

run "omit_ruleset" {
  command = plan

  variables {
    manage_ruleset = false
  }

  assert {
    condition     = length(restapi_object.main) == 0
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
          require_extra_approval_for_unattributed_changes = false
          dismissal_restriction = {
            enabled        = true
            allowed_actors = [{ id = 789, type = "Team" }]
          }
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
    condition     = restapi_object.main[0].data == jsonencode(var.ruleset)
    error_message = "Every custom field must reach the API, including dismissal actors and the unattributed-change approval setting."
  }
}

run "force_signatures_when_omitted" {
  command = plan

  variables {
    ruleset                     = merge(jsondecode(file("tests/fixtures/main-ruleset.json")), { rules = [] })
    ruleset_required_signatures = true
  }

  assert {
    condition     = jsondecode(restapi_object.main[0].data).rules == [{ type = "required_signatures" }]
    error_message = "The signature override must add the rule when it is absent from the object."
  }
}

run "reject_unknown_rule" {
  command = plan

  variables {
    ruleset = merge(jsondecode(file("tests/fixtures/main-ruleset.json")), { rules = [{ type = "unknown" }] })
  }

  expect_failures = [var.ruleset]
}

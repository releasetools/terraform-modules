"""Exercise the module's REST resource against a local ruleset API."""

import copy
import json
from pathlib import Path
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MODULE = Path(__file__).resolve().parents[1]
EXPECTED = json.loads((MODULE / "tests/fixtures/main-ruleset.json").read_text())
COLLECTION = "/repos/example/example/rulesets"
OBJECT = COLLECTION + "/23733932"


class RulesetAPI(BaseHTTPRequestHandler):
    stored = None
    writes = []

    def log_message(self, *_args):
        pass

    def respond(self, status, payload=None):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        if payload is not None:
            self.wfile.write(json.dumps(payload).encode())

    def do_GET(self):
        if self.path != OBJECT or self.stored is None:
            self.respond(404)
            return
        self.respond(200, self.stored)

    def write_ruleset(self, status):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        type(self).writes.append((self.command, copy.deepcopy(body)))
        type(self).stored = dict(body, id=23733932, node_id="RRS_test",
                                 source="example/example", source_type="Repository",
                                 created_at="2026-09-20T00:00:00Z",
                                 updated_at="2026-09-20T00:00:00Z",
                                 current_user_can_bypass="never", _links={})
        self.respond(status, self.stored)

    def do_POST(self):
        if self.path != COLLECTION:
            self.respond(404)
            return
        self.write_ruleset(201)

    def do_PUT(self):
        if self.path != OBJECT or self.stored is None:
            self.respond(404)
            return
        self.write_ruleset(200)

    def do_DELETE(self):
        if self.path != OBJECT:
            self.respond(404)
            return
        type(self).stored = None
        self.respond(204)


def main():
    with ThreadingHTTPServer(("127.0.0.1", 0), RulesetAPI) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            with tempfile.TemporaryDirectory(prefix="ruleset-lifecycle-") as directory:
                root = Path(directory)

                def terraform(*args, codes=(0,)):
                    result = subprocess.run(
                        ["terraform", *args], cwd=root, text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    )
                    if result.returncode not in codes:
                        raise AssertionError(result.stdout)
                    return result

                # Use the production resource with a fixed repository name.
                configuration = (MODULE / "configuration.tf").read_text()
                configuration = configuration[configuration.index("locals {"):]
                configuration = configuration.replace("github_repository.this.name", "var.name")
                (root / "main.tf").write_text(configuration)
                for filename in ("variables.tf", "versions.tf"):
                    (root / filename).write_text((MODULE / filename).read_text())
                (root / "provider.tf").write_text(
                    'provider "restapi" {\n'
                    f'  uri = "http://127.0.0.1:{server.server_port}"\n'
                    '  write_returns_object = true\n}\n'
                )
                (root / "terraform.tfvars.json").write_text(json.dumps({
                    "github_owner": "example", "name": "example",
                }))
                terraform("init", "-backend=false", "-input=false",
                          f"-plugin-dir={MODULE / '.terraform/providers'}")
                terraform("apply", "-auto-approve", "-input=false", "-no-color")
                assert RulesetAPI.writes == [("POST", EXPECTED)]
                terraform("plan", "-detailed-exitcode", "-input=false", "-no-color")

                for field, value in (
                    ("require_extra_approval_for_unattributed_changes", False),
                    ("dismissal_restriction", {"enabled": True, "allowed_actors": [{"id": 42, "type": "Team"}]}),
                ):
                    parameters = next(rule["parameters"] for rule in RulesetAPI.stored["rules"]
                                      if rule["type"] == "pull_request")
                    parameters[field] = value
                    terraform("plan", "-detailed-exitcode", "-input=false",
                              "-out=drift.tfplan", "-no-color", codes=(2,))
                    plan = json.loads(terraform("show", "-json", "drift.tfplan").stdout)
                    change = next(item["change"] for item in plan["resource_changes"]
                                  if item["address"] == "restapi_object.main[0]")
                    assert change["actions"] == ["update"], change
                    terraform("apply", "-input=false", "-no-color", "drift.tfplan")
                    assert RulesetAPI.writes[-1] == ("PUT", EXPECTED)
                    terraform("plan", "-detailed-exitcode", "-input=false", "-no-color")

                writes_before_import = len(RulesetAPI.writes)
                terraform("state", "rm", "restapi_object.main[0]")
                terraform("import", "-input=false", "restapi_object.main[0]", OBJECT)
                terraform("apply", "-auto-approve", "-input=false", "-no-color")
                assert all(method == "PUT" for method, _ in RulesetAPI.writes[writes_before_import:])
                assert RulesetAPI.stored["id"] == 23733932
                terraform("plan", "-detailed-exitcode", "-input=false", "-no-color")
                terraform("destroy", "-auto-approve", "-input=false", "-no-color")
                assert RulesetAPI.stored is None
                print("REST lifecycle passed: create, stable plan, both drift repairs, import, delete.")
        finally:
            server.shutdown()


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
# Create an automation GitHub App from manifest.json via the App-manifest flow,
# then store its credentials as GH_APP_* (org variables + secret, or print them
# for a personal-account app).
#
# Flow:
#   1. Choose the owner — an organization or your personal account.
#   2. Serve a local form that POSTs the manifest to GitHub.
#   3. You click "Create GitHub App" on GitHub (the one step that needs your
#      authenticated browser).
#   4. GitHub redirects back here with a one-time code.
#   5. Exchange the code; print the details and store the credentials.
#
# Env overrides: OWNER (org name, or your login / "@me" for a personal app; also
#   accepts the legacy ORG), APP_NAME (globally unique on GitHub), APP_URL
#   (homepage), PORT, VISIBILITY (all|private, org only), MANIFEST.
set -euo pipefail

PORT="${PORT:-8723}"
VISIBILITY="${VISIBILITY:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${MANIFEST:-$SCRIPT_DIR/../manifest.json}"

for c in gh jq python3; do
  command -v "$c" >/dev/null 2>&1 || { echo "error: missing dependency '$c'" >&2; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "error: run 'gh auth login' first" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "error: manifest not found: $MANIFEST" >&2; exit 1; }

USER_LOGIN="$(gh api user --jq .login)"

# Choose the owner (prompt unless OWNER/ORG was given).
OWNER="${OWNER:-${ORG:-}}"
if [ -z "$OWNER" ]; then
  echo "Where should the GitHub App live?"
  echo "  1) an organization"
  echo "  2) your personal account ($USER_LOGIN)"
  printf "Choice [1]: "
  read -r choice </dev/tty || choice=""
  if [ "$choice" = "2" ]; then
    OWNER="$USER_LOGIN"
  else
    printf "Organization name: "
    read -r OWNER </dev/tty || OWNER=""
    [ -n "$OWNER" ] || { echo "error: no organization given" >&2; exit 1; }
  fi
fi
[ "$OWNER" = "@me" ] && OWNER="$USER_LOGIN"

if [ "$OWNER" = "$USER_LOGIN" ]; then
  OWNER_KIND="user"
  NEW_APP_URL="https://github.com/settings/apps/new"
  INSTALL_API="/user/installations"
else
  OWNER_KIND="org"
  NEW_APP_URL="https://github.com/organizations/${OWNER}/settings/apps/new"
  INSTALL_API="/orgs/${OWNER}/installations"
fi
echo "Creating the app under the ${OWNER_KIND} '${OWNER}'."

# Fill the manifest placeholders. The name must be globally unique on GitHub;
# default both to something derived from the owner. Prompt unless given.
APP_NAME="${APP_NAME:-}"
if [ -z "$APP_NAME" ]; then
  printf "GitHub App name [%s]: " "${OWNER}-terraform"
  read -r APP_NAME </dev/tty || APP_NAME=""
  [ -n "$APP_NAME" ] || APP_NAME="${OWNER}-terraform"
fi

APP_URL="${APP_URL:-}"
if [ -z "$APP_URL" ]; then
  printf "App homepage URL [%s]: " "https://github.com/${OWNER}"
  read -r APP_URL </dev/tty || APP_URL=""
  [ -n "$APP_URL" ] || APP_URL="https://github.com/${OWNER}"
fi

REDIRECT="http://localhost:${PORT}/callback"
STATE="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
# Fill the manifest: point the redirect at our local listener and replace the
# <APP_NAME>/<APP_URL> placeholders with the values gathered above.
MANIFEST_JSON="$(jq -c \
  --arg r "$REDIRECT" \
  --arg n "$APP_NAME" \
  --arg u "$APP_URL" \
  '.redirect_url = $r | .name = $n | .url = $u' "$MANIFEST")"

WORKDIR="$(mktemp -d)"
SRV_PID=""
cleanup() {
  [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT
CODEFILE="$WORKDIR/code"

# Local server: GET / auto-submits the manifest form to GitHub; GET /callback
# captures ?code= (after verifying state) and writes it to CODEFILE.
MANIFEST_JSON="$MANIFEST_JSON" STATE="$STATE" NEW_APP_URL="$NEW_APP_URL" PORT="$PORT" CODEFILE="$CODEFILE" \
  python3 - <<'PY' &
import html, os, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

manifest = os.environ["MANIFEST_JSON"]
state    = os.environ["STATE"]
base     = os.environ["NEW_APP_URL"]
port     = int(os.environ["PORT"])
codefile = os.environ["CODEFILE"]
action   = f"{base}?state={urllib.parse.quote(state)}"

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode())

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/callback":
            q = urllib.parse.parse_qs(u.query)
            if q.get("state", [""])[0] != state:
                self._send("<h2>State mismatch — aborted.</h2>")
                return
            with open(codefile, "w") as f:
                f.write(q.get("code", [""])[0])
            self._send("<h2>App created. Close this tab and return to the terminal.</h2>")
            return
        self._send(
            "<!doctype html><meta charset=utf-8>"
            "<body onload='document.forms[0].submit()'>"
            f"<form action='{html.escape(action)}' method='post'>"
            f"<input type=hidden name=manifest value='{html.escape(manifest)}'>"
            "<noscript><button>Create the GitHub App</button></noscript>"
            "</form><p>Sending you to GitHub to create the app…</p></body>"
        )

HTTPServer(("127.0.0.1", port), H).serve_forever()
PY
SRV_PID=$!

URL="http://localhost:${PORT}/"
echo "Opening ${URL} — approve the app on GitHub (click 'Create GitHub App')."
( command -v open    >/dev/null 2>&1 && open "$URL" ) \
  || ( command -v xdg-open >/dev/null 2>&1 && xdg-open "$URL" ) \
  || echo "Open this URL in your browser: $URL"

echo "Waiting for the GitHub redirect (up to 5 minutes)…"
for _ in $(seq 1 300); do
  [ -s "$CODEFILE" ] && break
  sleep 1
done
kill "$SRV_PID" 2>/dev/null || true; SRV_PID=""
CODE="$(cat "$CODEFILE" 2>/dev/null || true)"
[ -n "$CODE" ] || { echo "error: no code received (timed out or cancelled)" >&2; exit 1; }

echo "Exchanging the code for credentials…"
RESP="$(gh api -X POST "/app-manifests/${CODE}/conversions")" \
  || { echo "error: code exchange failed (codes expire after 1 hour)" >&2; exit 1; }

APP_ID="$(jq -r '.id' <<<"$RESP")"
SLUG="$(jq -r '.slug' <<<"$RESP")"
CLIENT_ID="$(jq -r '.client_id' <<<"$RESP")"
HTML_URL="$(jq -r '.html_url' <<<"$RESP")"
APP_OWNER="$(jq -r '.owner.login' <<<"$RESP")"
PEM_FILE="$WORKDIR/private-key.pem"
(umask 077; jq -r '.pem' <<<"$RESP" >"$PEM_FILE")

echo
echo "App created:"
echo "  slug      : $SLUG"
echo "  app id    : $APP_ID"
echo "  client id : $CLIENT_ID"
echo "  owner     : $APP_OWNER"
echo "  settings  : $HTML_URL"
echo

if [ "$APP_OWNER" != "$OWNER" ]; then
  echo "warning: the app was created under '$APP_OWNER', not the '$OWNER' you chose." >&2
  echo "         (delete it at $HTML_URL and re-run, picking the right owner.)" >&2
fi

if [ "$OWNER_KIND" = "org" ]; then
  echo "Storing org-level credentials on '$APP_OWNER' (visibility: $VISIBILITY)…"
  gh variable set GH_APP_ID        --org "$APP_OWNER" --visibility "$VISIBILITY" --body "$APP_ID"
  gh variable set GH_APP_CLIENT_ID --org "$APP_OWNER" --visibility "$VISIBILITY" --body "$CLIENT_ID"
  gh secret   set GH_APP_PRIVATE_KEY --org "$APP_OWNER" --visibility "$VISIBILITY" <"$PEM_FILE"
  echo "Set org variables GH_APP_ID, GH_APP_CLIENT_ID and org secret GH_APP_PRIVATE_KEY."
else
  KEEP="$(mktemp -t ghapp-private-key.XXXXXX.pem)"
  cp "$PEM_FILE" "$KEEP"
  echo "Personal account — GitHub has no account-level Actions secrets, so set"
  echo "GH_APP_* where your workflow runs (per repo). For example:"
  echo "  gh variable set GH_APP_CLIENT_ID -R $APP_OWNER/<repo> --body $CLIENT_ID"
  echo "  gh secret   set GH_APP_PRIVATE_KEY -R $APP_OWNER/<repo> < $KEEP"
  echo "Saved the private key to: $KEEP  (delete it after setting the secret)."
fi
echo

cat <<EOF
Next:
  1. Install the app on the repos it manages (choose "Only select repositories"):
       ${HTML_URL}/installations/new
  2. Pin which repos the installation can reach with the Terraform module in
     this repo (see README.md). Its installation id:
       gh api "${INSTALL_API}" --jq '.installations[] | select(.app_slug=="${SLUG}") | .id'
EOF

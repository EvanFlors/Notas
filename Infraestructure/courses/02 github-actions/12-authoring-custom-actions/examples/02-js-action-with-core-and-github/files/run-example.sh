#!/usr/bin/env bash
# Scaffolds a minimal JS action and runs it locally the same way the runner
# would: `node dist/index.js` with INPUT_* and GITHUB_* env vars.
# To avoid requiring `npm install`, we vendor tiny stubs of
# @actions/core and @actions/github into node_modules/.
set -euo pipefail

DEMO="${1:-/tmp/js-action-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO/repo-echo-pr-info"
cd "$DEMO/repo-echo-pr-info"

mkdir -p src dist node_modules/@actions/core node_modules/@actions/github

# ---------- action.yml ----------
cat > action.yml <<'EOF'
name: "Echo PR info"
description: "Reads a label input and emits a greeting + context info as outputs."
author: "demo"
branding:
  icon: "info"
  color: "blue"

inputs:
  label:
    description: "Label text to include in the greeting"
    required: false
    default: "hello"

outputs:
  greeting:
    description: "The computed greeting"
  event:
    description: "Event name as seen by the action"

runs:
  using: node20
  main: dist/index.js
EOF

# ---------- package.json ----------
cat > package.json <<'EOF'
{
  "name": "echo-pr-info",
  "version": "1.0.0",
  "private": true,
  "main": "dist/index.js",
  "scripts": {
    "build": "ncc build src/index.js -o dist"
  },
  "dependencies": {
    "@actions/core": "^1.11.0",
    "@actions/github": "^6.0.0"
  }
}
EOF

# ---------- src/index.js (what you'd actually author) ----------
cat > src/index.js <<'EOF'
const core   = require('@actions/core');
const github = require('@actions/github');

async function run() {
  try {
    const label = core.getInput('label') || 'hello';
    const ctx = github.context;
    const greeting = `${label} from ${ctx.repo?.owner || 'local'}/${ctx.repo?.repo || 'local'}`;

    core.info(`event: ${ctx.eventName || 'local'}`);
    core.info(greeting);

    core.setOutput('greeting', greeting);
    core.setOutput('event', ctx.eventName || 'local');
  } catch (err) {
    core.setFailed(err.message);
  }
}

run();
EOF

# ---------- dist/index.js (what the runner actually runs) ----------
# In a real repo this is `npm run build` with ncc; here we vendor the exact
# same source so the example is runnable without npm install.
cp src/index.js dist/index.js

# ---------- vendored minimal @actions/core ----------
cat > node_modules/@actions/core/package.json <<'EOF'
{"name":"@actions/core","version":"0.0.0-stub","main":"index.js"}
EOF
cat > node_modules/@actions/core/index.js <<'EOF'
// Minimal stub mimicking the real @actions/core for local demos.
// Enough for getInput / setOutput / info / warning / error / setFailed.
const fs = require('fs');

function getInput(name, opts = {}) {
  const key = 'INPUT_' + name.replace(/ /g, '_').toUpperCase();
  const val = (process.env[key] || '').trim();
  if (opts.required && !val) throw new Error(`Input required and not supplied: ${name}`);
  return val;
}

function _appendFile(envVar, line) {
  const target = process.env[envVar];
  if (target) fs.appendFileSync(target, line + '\n');
}

function setOutput(name, value) {
  // GitHub expects: name=value in $GITHUB_OUTPUT (multiline uses heredoc).
  const str = String(value);
  if (str.includes('\n')) {
    const d = '__ENDOFVALUE__' + Math.random().toString(36).slice(2);
    _appendFile('GITHUB_OUTPUT', `${name}<<${d}\n${str}\n${d}`);
  } else {
    _appendFile('GITHUB_OUTPUT', `${name}=${str}`);
  }
}

function exportVariable(name, value) {
  _appendFile('GITHUB_ENV', `${name}=${value}`);
}
function addPath(p) { _appendFile('GITHUB_PATH', p); }

function info(msg)    { process.stdout.write(String(msg) + '\n'); }
function debug(msg)   { if (process.env.ACTIONS_STEP_DEBUG === 'true') process.stdout.write('::debug::' + msg + '\n'); }
function warning(msg) { process.stdout.write('::warning::' + msg + '\n'); }
function error(msg)   { process.stdout.write('::error::' + msg + '\n'); }
function notice(msg)  { process.stdout.write('::notice::' + msg + '\n'); }
function setFailed(msg) {
  error(msg);
  process.exitCode = 1;
}

module.exports = {
  getInput, setOutput, exportVariable, addPath,
  info, debug, warning, error, notice, setFailed,
};
EOF

# ---------- vendored minimal @actions/github ----------
cat > node_modules/@actions/github/package.json <<'EOF'
{"name":"@actions/github","version":"0.0.0-stub","main":"index.js"}
EOF
cat > node_modules/@actions/github/index.js <<'EOF'
// Minimal stub mimicking the real @actions/github context object.
const fs = require('fs');

function parseRepo() {
  const r = process.env.GITHUB_REPOSITORY || '';
  const [owner, repo] = r.split('/');
  return owner && repo ? { owner, repo } : {};
}

function loadPayload() {
  const p = process.env.GITHUB_EVENT_PATH;
  if (!p) return {};
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
  catch { return {}; }
}

const context = {
  eventName: process.env.GITHUB_EVENT_NAME || '',
  sha:       process.env.GITHUB_SHA || '',
  ref:       process.env.GITHUB_REF || '',
  workflow:  process.env.GITHUB_WORKFLOW || '',
  actor:     process.env.GITHUB_ACTOR || '',
  repo:      parseRepo(),
  payload:   loadPayload(),
};

function getOctokit(/* token */) {
  // Real implementation returns a REST+GraphQL client. Not used in this demo.
  throw new Error('getOctokit() not implemented in local stub');
}

module.exports = { context, getOctokit };
EOF

echo "== Scaffolded JS action at: $DEMO/repo-echo-pr-info =="
echo

# ---------- Run it like the runner would ----------
if ! command -v node >/dev/null 2>&1; then
  echo "node not installed. Install Node 20+ to run the demo:"
  echo "  macOS:   brew install node"
  echo "  Linux:   https://nodejs.org/en/download"
  echo "Skipping execution; files are in place."
  exit 0
fi

echo "== Running: node dist/index.js (simulated runner invocation) =="
export GITHUB_OUTPUT="$DEMO/github_output"
: > "$GITHUB_OUTPUT"

INPUT_LABEL="hola" \
GITHUB_REPOSITORY="demo-owner/demo-repo" \
GITHUB_EVENT_NAME="push" \
  node dist/index.js

echo
echo "== Contents of \$GITHUB_OUTPUT (what the caller consumes) =="
cat "$GITHUB_OUTPUT"
echo
echo "Done."

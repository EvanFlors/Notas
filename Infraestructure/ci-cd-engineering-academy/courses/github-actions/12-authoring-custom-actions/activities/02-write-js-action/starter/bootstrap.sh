#!/usr/bin/env bash
# Bootstraps the JS action scaffold for gha-12-02.
# Provides:
#   - action.yml skeleton (TODOs)
#   - src/index.js skeleton (TODOs)
#   - dist/ (empty; student will copy from src/ or use ncc)
#   - node_modules/@actions/core (vendored stub so students can work offline)
#   - fixtures/ with 3 known files (3 + 5 + 10 lines)
#   - package.json
set -euo pipefail

BASE="${1:-/tmp/js-action-lab}"
rm -rf "$BASE"
ACTION="$BASE/line-counter"
mkdir -p "$ACTION/src" "$ACTION/dist" "$ACTION/fixtures" \
         "$ACTION/node_modules/@actions/core"
cd "$ACTION"

# ---------- action.yml skeleton ----------
cat > action.yml <<'EOF'
# TODO: complete per README.md — set name, description, inputs, outputs,
# and runs (using: node20, main: dist/index.js).

name: "TODO"
description: "TODO"
author: "TODO"
branding:
  icon: "bar-chart-2"
  color: "purple"

inputs:
  path:
    description: "TODO"
    required: true
  # TODO: pattern (default '**/*')
  # TODO: fail-threshold (default '0')

outputs:
  total-lines:
    description: "TODO"
  # TODO: file-count, top-file

runs:
  using: node20
  main: dist/index.js
EOF

# ---------- src/index.js skeleton ----------
cat > src/index.js <<'EOF'
// TODO: implement per README.md.
//
// Steps:
//   1. Read inputs with core.getInput: path (required), pattern, fail-threshold.
//   2. Enumerate files matching pattern under path.
//   3. For each file, count lines (number of '\n' + 1 if last char != '\n', or
//      number of lines returned by splitting on '\n'; be deterministic).
//   4. Set outputs: total-lines, file-count, top-file.
//   5. If fail-threshold > 0 and total > threshold, core.setFailed(...).

const core = require('@actions/core');
// const fs = require('fs');
// const path = require('path');

async function run() {
  try {
    // TODO
    core.setFailed('not implemented');
  } catch (err) {
    core.setFailed(err.message);
  }
}

run();
EOF

# ---------- package.json ----------
cat > package.json <<'EOF'
{
  "name": "line-counter",
  "version": "0.1.0",
  "private": true,
  "main": "dist/index.js",
  "scripts": {
    "build": "ncc build src/index.js -o dist"
  },
  "dependencies": {
    "@actions/core": "^1.11.0"
  }
}
EOF

# ---------- vendored stub of @actions/core ----------
cat > node_modules/@actions/core/package.json <<'EOF'
{"name":"@actions/core","version":"0.0.0-stub","main":"index.js"}
EOF
cat > node_modules/@actions/core/index.js <<'EOF'
// Minimal stub of @actions/core, enough for this lab.
const fs = require('fs');

function getInput(name, opts = {}) {
  // Real @actions/core only replaces spaces with underscores; hyphens stay.
  // For ergonomic bash-local testing (bash vars can't contain '-') we also
  // try the fully underscored variant.
  const upper = name.toUpperCase();
  const k1 = 'INPUT_' + upper.replace(/ /g, '_');            // real runner
  const k2 = 'INPUT_' + upper.replace(/[ -]/g, '_');         // local-test fallback
  const val = ((process.env[k1] ?? process.env[k2]) || '').trim();
  if (opts.required && !val) throw new Error(`Input required and not supplied: ${name}`);
  return val;
}

function getBooleanInput(name, opts = {}) {
  const v = getInput(name, opts).toLowerCase();
  if (['true','yes','1','on'].includes(v))  return true;
  if (['false','no','0','off',''].includes(v)) return false;
  throw new Error(`Input is not a boolean: ${name}=${v}`);
}

function _append(envVar, line) {
  const t = process.env[envVar];
  if (t) fs.appendFileSync(t, line + '\n');
}
function setOutput(name, value) {
  const s = String(value);
  if (s.includes('\n')) {
    const d = '__EOF__' + Math.random().toString(36).slice(2);
    _append('GITHUB_OUTPUT', `${name}<<${d}\n${s}\n${d}`);
  } else {
    _append('GITHUB_OUTPUT', `${name}=${s}`);
  }
}
function exportVariable(n,v) { _append('GITHUB_ENV', `${n}=${v}`); }
function addPath(p)          { _append('GITHUB_PATH', p); }

function info(m)    { process.stdout.write(String(m)+'\n'); }
function debug(m)   { if (process.env.ACTIONS_STEP_DEBUG === 'true') process.stdout.write('::debug::'+m+'\n'); }
function warning(m) { process.stdout.write('::warning::'+m+'\n'); }
function error(m)   { process.stdout.write('::error::'+m+'\n'); }
function notice(m)  { process.stdout.write('::notice::'+m+'\n'); }
function setFailed(m) { error(m); process.exitCode = 1; }

module.exports = {
  getInput, getBooleanInput, setOutput, exportVariable, addPath,
  info, debug, warning, error, notice, setFailed,
};
EOF

# ---------- fixtures: known-line-count files ----------
printf 'line1\nline2\nline3\n' > fixtures/a.txt      # 3 lines
printf 'l1\nl2\nl3\nl4\nl5\n' > fixtures/b.txt       # 5 lines
printf 'p1\np2\np3\np4\np5\np6\np7\np8\np9\np10\n' > fixtures/c.py  # 10 lines

echo "Starter ready at: $ACTION"
echo "Fixtures: a.txt(3)  b.txt(5)  c.py(10)  total=18"
echo
echo "Next:"
echo "  1. Edit action.yml and src/index.js per README.md"
echo "  2. Copy src/index.js to dist/index.js (or run 'npm run build' if you install ncc)"
echo "  3. Test:   INPUT_PATH=./fixtures node dist/index.js"
echo "  4. Validate:  bash tests/validate.sh $BASE"

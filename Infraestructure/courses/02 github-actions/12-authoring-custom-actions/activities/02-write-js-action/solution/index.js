// Reference solution for gha-12-02-write-js-action.
// Counts lines across files matching a simple glob under a path.
const core = require('@actions/core');
const fs   = require('fs');
const path = require('path');

function walk(dir, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, acc);
    else if (entry.isFile()) acc.push(full);
  }
  return acc;
}

function matches(file, pattern) {
  if (!pattern || pattern === '**/*') return true;
  // Only support simple suffix glob '**/*.ext' for this lab.
  const m = pattern.match(/^\*\*\/\*(\.[A-Za-z0-9]+)$/);
  if (m) return file.endsWith(m[1]);
  return file.endsWith(pattern); // fallback: substring suffix
}

function countLines(file) {
  const buf = fs.readFileSync(file, 'utf8');
  if (buf.length === 0) return 0;
  // Count newlines; if file does not end with \n, add 1 for the final line.
  let n = 0;
  for (const ch of buf) if (ch === '\n') n++;
  if (buf[buf.length - 1] !== '\n') n++;
  return n;
}

async function run() {
  try {
    const inputPath = core.getInput('path', { required: true });
    const pattern   = core.getInput('pattern') || '**/*';
    const threshold = parseInt(core.getInput('fail-threshold') || '0', 10);

    if (!fs.existsSync(inputPath)) {
      throw new Error(`path not found: ${inputPath}`);
    }

    let files = [];
    const stat = fs.statSync(inputPath);
    if (stat.isFile()) files = [inputPath];
    else if (stat.isDirectory()) files = walk(inputPath);

    files = files.filter(f => matches(f, pattern));

    let total = 0, top = '', topN = -1;
    for (const f of files) {
      const n = countLines(f);
      total += n;
      if (n > topN) { topN = n; top = f; }
    }

    core.info(`matched ${files.length} files, ${total} lines total`);
    core.setOutput('total-lines', String(total));
    core.setOutput('file-count',  String(files.length));
    core.setOutput('top-file',    files.length ? top : '');

    if (threshold > 0 && total > threshold) {
      core.setFailed(`total lines ${total} exceeds fail-threshold ${threshold}`);
    }
  } catch (err) {
    core.setFailed(err.message);
  }
}

run();

# Example 02 — Bootstrap repo skeleton

> **Goal:** show a minimal but realistic layout for a bootstrap repo and a root
> `ApplicationSet` that discovers add-ons by directory.

## Layout

```
bootstrap-repo/
├── bootstrap/
│   └── root.yaml                 # The ONE manifest you apply by hand
├── projects/
│   └── platform.yaml             # AppProject for platform add-ons
├── addons/
│   ├── cert-manager/application.yaml
│   ├── ingress-nginx/application.yaml
│   └── metrics-server/application.yaml
└── apps/
    └── guestbook/application.yaml
```

Everything under `addons/*` becomes an Application via the root `ApplicationSet` with a
**Git generator** that iterates over the directories. Adding a new add-on = `mkdir
addons/<name> && cp application.yaml.template addons/<name>/`.

## Why directory-driven

- No controller edits needed to add/remove add-ons.
- The repo is self-documenting: *see a folder, see what it deploys*.
- CODEOWNERS can be per-folder (`addons/cert-manager/* @platform-security`).

## How to use

This example is **static documentation** — the YAML is meant to live in a Git repo. To
exercise it end-to-end against a real cluster, use `activity 02` (which has a working
starter that commits this layout to a local repo and applies the root).

To just lint the YAML:

```bash
kubectl --dry-run=client -f bootstrap/root.yaml apply 2>&1 | head
# Or if you want full validation (needs the Argo CRDs installed):
kubectl apply --dry-run=server -f bootstrap/root.yaml
```

## Internals to notice

- `bootstrap/root.yaml` is an **`ApplicationSet`**, not an `Application` — because the
  root for a multi-add-on repo is better expressed as "a template × a generator" than as
  a hand-written Application per add-on.
- The template uses `{{path.basename}}` to name each Application after its folder.
- `project: platform` is referenced; `projects/platform.yaml` must be applied first.
  In practice, the root ApplicationSet uses `syncOptions: [SkipDryRunOnMissingResource=true]`
  to tolerate the first-apply chicken-and-egg (the Project will land soon).
- The `apps/` tree is a separate ApplicationSet in a real repo (not shown here) to keep
  the add-ons/apps boundaries clean.

# Starter (independent activity)

This activity is independent — there is no scaffold to fill in. Create the
`platform/` chart tree from scratch under this directory (`starter/platform/`),
following the specification in `../README.md` §5.

Expected final tree:

```
starter/
└── platform/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-airgapped.yaml
    └── charts/
        ├── web/
        │   ├── Chart.yaml
        │   ├── values.yaml
        │   └── templates/
        │       └── configmap.yaml
        └── worker/
            ├── Chart.yaml
            ├── values.yaml
            └── templates/
                └── configmap.yaml
```

Then validate from the activity directory:

```bash
CHART_DIR="$(pwd)/starter/platform" bash tests/validate.sh
```

If you get stuck, consult `../solution/platform/` AFTER making a real attempt.

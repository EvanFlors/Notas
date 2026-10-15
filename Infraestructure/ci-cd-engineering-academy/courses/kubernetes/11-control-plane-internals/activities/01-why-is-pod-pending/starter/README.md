# Starter

Run from the activity directory:

```bash
bash starter/create-pending-pod.sh
```

That applies a Pod `pending-mystery` with an impossible `nodeSelector`.
The Pod will stay `Pending`. Diagnose it, document the root cause in
`/tmp/kube-pending/ANALYSIS.md`, then run `bash tests/validate.sh`.

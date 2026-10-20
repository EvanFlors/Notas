# Reference — gcp-04-02

Checklist:

- `cloud-run.tf` tiene `google_cloud_run_v2_service` con `template.revision = "capstone-api-v2"`.
- Dos bloques `traffic{}`: uno con `revision="capstone-api-v1" percent=95`, otro con `revision="capstone-api-v2" percent=5`.
- `template.service_account` apunta a una SA no-default.
- `README-INTENT.md` menciona Canary, los dos nombres de revision y un procedimiento de rollback.

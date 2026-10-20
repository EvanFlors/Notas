# Recursos

## Cloud Run

- [Cloud Run — overview](https://cloud.google.com/run/docs/overview/what-is-cloud-run)
- [Cloud Run container contract](https://cloud.google.com/run/docs/container-contract) — por que leer `$PORT`, non-root, etc.
- [Traffic splitting & revisions](https://cloud.google.com/run/docs/managing/revisions)
- [CPU allocation (`cpu_idle` / always allocated)](https://cloud.google.com/run/docs/configuring/cpu-allocation)
- [Cloud Run jobs](https://cloud.google.com/run/docs/create-jobs)
- [gVisor en Cloud Run](https://cloud.google.com/run/docs/securing/execution-environments)

## Cloud Functions

- [Functions gen 2 overview](https://cloud.google.com/functions/docs/concepts/version-comparison)
- [Functions Framework for Python](https://github.com/GoogleCloudPlatform/functions-framework-python)

## Compute Engine

- [Instance templates](https://cloud.google.com/compute/docs/instance-templates)
- [Managed Instance Groups](https://cloud.google.com/compute/docs/instance-groups)
- [Spot VMs](https://cloud.google.com/compute/docs/instances/spot)
- [OS Login](https://cloud.google.com/compute/docs/oslogin)
- [Shielded VM](https://cloud.google.com/compute/shielded-vm/docs/shielded-vm)

## Terraform providers

- [`google_cloud_run_v2_service`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service)
- [`google_cloud_run_v2_job`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_job)
- [`google_cloudfunctions2_function`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions2_function)
- [`google_compute_instance_template`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template)
- [`google_compute_region_instance_group_manager`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager)

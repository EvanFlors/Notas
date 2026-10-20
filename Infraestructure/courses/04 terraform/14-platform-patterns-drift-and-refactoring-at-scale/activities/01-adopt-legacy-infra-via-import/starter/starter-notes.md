# Starter notes — tf-14-01

You are in the working directory: `/tmp/tf14-act01/`.

Legacy files to adopt live at: `/tmp/tf14-act01-legacy/`.

## Expected final layout

```
/tmp/tf14-act01/
├── versions.tf           (provided)
├── imports.tf            (you edited: 3 import {} blocks)
├── adopted.tf            (you created: cleaned resource {} blocks)
├── terraform.tfstate     (produced by apply)
├── .terraform/           (produced by init)
└── .terraform.lock.hcl   (produced by init)
```

## Done when

- `terraform plan` reports **No changes**.
- `terraform state list` shows `local_file.app_alpha`, `local_file.app_beta`, `local_file.app_gamma`.
- Legacy files are unchanged on disk.

## Hints (reveal only if stuck)

- `-generate-config-out` refuses to overwrite an existing file; delete `generated.tf` and retry.
- The generated HCL may include `content_base64` or `source` fields set to defaults — strip them, keep `filename` + `content` + `file_permission`.
- The `id` of a `local_file` is the absolute path.

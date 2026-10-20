# Starter — tf-05-02

Copia a `/tmp/` y trabaja ahí:

```bash
WORK=/tmp/tf-05-02-inspect
rm -rf "$WORK" && mkdir -p "$WORK"
cp -R . "$WORK/"
cd "$WORK"

terraform init
terraform apply -auto-approve

# Luego:
#  1. Copia NOTES.template.md -> NOTES.md
#  2. Rellena NOTES.md usando `terraform state list`/`show` y jq/grep sobre terraform.tfstate.
#  3. Valida con bash tests/validate.sh /tmp/tf-05-02-inspect (desde el repo).
```

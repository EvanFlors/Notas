# Solución — tf-10-02

Ambas respuestas son válidas; lo importante es que la **decisión** sea
consistente con el estado final.

Nota didáctica: `local_file` identifica al recurso por hash del content que
él escribió. Cuando el content en disco difiere, el provider reporta "ya no
existe" (no "cambió"). Por eso aceptar drift aquí implica también retirar
el bloque de la HCL (o re-importar con `terraform import` tras alinear el
content). Un `aws_instance` con tag drift no funcionaría igual: ahí
accept = `apply refresh.tfplan` + actualizar el tag en la HCL.

## Camino A — accept

```bash
cd /tmp/tf-10-02
echo "hotfix: parche manual del 2026-10-15" > note.txt
terraform plan -refresh-only -out=refresh.tfplan
terraform apply refresh.tfplan           # state pierde local_file.note
# retirar el bloque del HCL (adoptar el archivo como no-gestionado):
cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}
EOF
terraform plan                            # No changes.
```

`decision.md`:

```markdown
# Decisión
## Camino elegido
accept
## Justificación
El hotfix es intencional y debe preservarse. Dado que local_file identifica
al recurso por hash, lo retiro de la HCL y lo adopto como archivo
no-gestionado por ahora; en el PR siguiente lo re-declaro con el content
nuevo e `import` si queremos volver a gestionarlo.
```

## Camino B — revert

```bash
cd /tmp/tf-10-02
echo "hotfix: parche manual del 2026-10-15" > note.txt
terraform plan -refresh-only -out=refresh.tfplan
rm refresh.tfplan
terraform apply -auto-approve
terraform plan                            # No changes.
```

`decision.md`:

```markdown
# Decisión
## Camino elegido
revert
## Justificación
El cambio no está documentado ni autorizado por el proceso de change-mgmt.
Volvemos al estado deseado codificado en main.tf; cualquier excepción debe
pasar por un PR.
```

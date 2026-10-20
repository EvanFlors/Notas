# Ejemplo 02 — `ignore_changes` para atributos modificados fuera de banda

## Concepto que demuestra

- Un recurso cuyo contenido es modificado por **otro sistema** entre `apply`s (SCPs que inyectan tags, auto-scalers que modifican capacidad, agentes que rotan credenciales).
- `lifecycle { ignore_changes = [attr] }` evita que TF revierta ese cambio en cada plan.

Simulamos "otro sistema" editando el archivo a mano entre `apply`s. Un `local_file` sin `ignore_changes` lo "cura" automáticamente (sobrescribe); con `ignore_changes = [content]`, lo ignora.

## Prerrequisitos

- Terraform ≥ 1.5 o OpenTofu ≥ 1.6.
- Permiso de escritura en `/tmp/`.

## Ejecución

```bash
rm -rf /tmp/tf-09-ex02 && mkdir -p /tmp/tf-09-ex02 && cd /tmp/tf-09-ex02
```

Crea `main.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

resource "local_file" "config" {
  filename = "/tmp/tf-09-ex02/config.yaml"
  content  = "owner: terraform\nversion: 1\n"

  # Comentario: con esta línea, TF deja de reclamar cambios en 'content'.
  # Sin ella, cualquier edición externa se "cura" en el próximo apply.
  lifecycle {
    ignore_changes = [content]
  }
}
```

Primer apply:

```bash
terraform init
terraform apply -auto-approve
cat /tmp/tf-09-ex02/config.yaml
```

Ahora **simula** que otro sistema modifica el archivo:

```bash
echo "owner: scp-injector" >> /tmp/tf-09-ex02/config.yaml
cat /tmp/tf-09-ex02/config.yaml
```

Corré plan:

```bash
terraform plan
```

Verás `No changes. Your infrastructure matches the configuration.` — TF **leyó** el nuevo contenido en el refresh, lo guardó en el state, pero **no generó diff** porque está en `ignore_changes`.

## Prueba de control: sin `ignore_changes`

Edita `main.tf` y elimina el bloque `lifecycle`:

```hcl
resource "local_file" "config" {
  filename = "/tmp/tf-09-ex02/config.yaml"
  content  = "owner: terraform\nversion: 1\n"
}
```

Repite la simulación:

```bash
echo "owner: scp-injector" >> /tmp/tf-09-ex02/config.yaml
terraform plan
```

Ahora el plan muestra `~ content` — TF propone sobrescribir el cambio externo. Un `apply` lo haría. Eso es el "modo cura automática", que a veces querés y a veces no.

## Variantes útiles

- `ignore_changes = [tags]` — lista completa de tags.
- `ignore_changes = [tags["Owner"]]` — solo un key del mapa.
- `ignore_changes = all` — todos los atributos del recurso. Brocha gorda; es raro que sea lo correcto fuera de "voy a adoptar este recurso y lo iré refinando".

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf /tmp/tf-09-ex02
```

## Observación

`ignore_changes` **no borra el drift**. Lo ignora activamente. El valor real queda registrado en el state (si lees `terraform show`, lo vas a ver). Eso es importante: la **trazabilidad** se mantiene, el **diff visual** desaparece.

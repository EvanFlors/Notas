# Ejemplo 03 — Reconciliar drift con `-refresh-only`

Objetivo: ver qué hace `terraform plan -refresh-only`, cómo lo lees, y qué decisión tomas (aceptar vs revertir el drift).

## Prerrequisitos

- Terraform ≥ 1.5.

## Setup

```bash
mkdir -p /tmp/tf-10-ex03 && cd /tmp/tf-10-ex03

cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

resource "local_file" "note" {
  filename = "${path.module}/note.txt"
  content  = "versión gestionada por terraform\n"
}
EOF

terraform init
terraform apply -auto-approve
cat note.txt
```

## Pasos

### 1. Introducir drift manualmente

```bash
echo "editado a mano fuera de terraform" > note.txt
cat note.txt
```

### 2. Plan normal: Terraform propone revertir

```bash
terraform plan
```

Verás `local_file.note` marcado como update/replace para volver al `content` de la config. **No apliques todavía.**

### 3. Plan `-refresh-only`: solo reporta drift

```bash
terraform plan -refresh-only -out=refresh.tfplan
```

Observa el mensaje: "Objects have changed outside of Terraform". El plan no propone cambios de infra; propone actualizar el state para reflejar la realidad.

### 4. Dos caminos

**Camino A — aceptar el drift** (adoptar lo que la realidad dice):

```bash
# aplica el refresh plan: el state deja de rastrear el local_file.
# OJO: `local_file` identifica al recurso por hash del content. Cuando
# el content difiere, el provider reporta "resource gone" (no "changed").
# Resultado del apply: la entrada sale del state (el archivo sigue en disco).
terraform apply refresh.tfplan

# Para que `plan` sea no-op, retira el bloque del HCL (adopción fuera de TF)
# o re-importa con `terraform import` tras alinear el content en HCL.
# A mano: borra el bloque `resource "local_file" "note" { ... }` de main.tf.
terraform plan   # ahora sí: No changes.
```

Aceptar drift tiene **dos pasos**: `apply refresh.tfplan` (reconcilia state) y alinear la config (reconcilia la intención). Con providers "normales" (p. ej. tags de AWS) basta con actualizar el valor en HCL; con `local_file` el camino limpio es retirar la declaración o importar.

**Camino B — revertir el drift** (pisar la realidad con la config):

```bash
# descarta el refresh plan y aplica el plan normal
rm refresh.tfplan
terraform apply -auto-approve
cat note.txt   # vuelve al contenido de la config
```

### 5. Cuándo escoger qué

| Situación | Camino recomendado |
|---|---|
| El cambio manual fue un hotfix legítimo que debe quedarse | A, y luego PR actualizando la config |
| El cambio manual fue un error | B |
| No sabes quién lo hizo ni por qué | **ninguno**; investiga primero |

## Preguntas

1. ¿Por qué `-refresh-only` necesita `-out` + `apply` separado para persistir el cambio al state?
2. ¿Qué pasaría si saltas `-refresh-only` y aplicas `plan` directamente? ¿Qué pierdes?
3. ¿Cómo diferirías este flujo si trabajaras con un backend remoto compartido en equipo?

## Limpieza

```bash
cd / && rm -rf /tmp/tf-10-ex03
```

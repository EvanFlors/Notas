# Ejemplo 02 — `dynamic` para expandir N sub-bloques en un recurso

Un `dynamic` block expande sub-bloques repetidos **dentro de un recurso**. Para enseñar la mecánica sin usar cloud, este ejemplo cumple dos cosas:

1. Muestra el patrón real como lo verías con `aws_security_group` (en `security-group.tf.example`, no se aplica).
2. Usa `templatefile` + una `for` expression para **renderizar** la misma expansión y escribirla en un archivo local (`out/web-sg.rendered.tf`), que te permite comparar la fuente (datos) con la salida (sub-bloques).

Es el mismo pipeline de datos que alimenta a `dynamic`, con feedback visual.

## Archivos

- `main.tf` — lee `var.rules`, aplana con `for`, usa `templatefile` para renderizar un `aws_security_group` como texto en `out/`.
- `variables.tf` — tipo de `rules`.
- `terraform.tfvars` — 3 reglas de ingress.
- `sg.tftpl` — template Go que itera sobre `rules`.
- `security-group.tf.example` — el patrón real con `dynamic "ingress"` (referencia, **no se aplica**).

## Cómo correrlo

```bash
cd examples/02-dynamic-ingress-rules
terraform init
terraform apply -auto-approve
cat out/web-sg.rendered.tf
```

Verás 3 bloques `ingress { ... }` renderizados, uno por regla del `.tfvars`.

## Experimentos sugeridos

1. Añade una regla en `terraform.tfvars` → `terraform apply` → `cat out/web-sg.rendered.tf` muestra 4 bloques.
2. Lee `security-group.tf.example`. Observa que el `dynamic "ingress"` **produce la misma expansión** que tu template, pero en memoria y la pasa al provider en vez de a un archivo.
3. Elimina `rules` y pon `rules = []`. El archivo renderiza sin ningún bloque `ingress`.

## Puntos clave

- `dynamic` expande sub-bloques; **no crea recursos**. Para N recursos: `for_each` sobre el recurso.
- El `for_each` de `dynamic` acepta list, set o map; el iterador por defecto se llama como el sub-bloque (`ingress.value`, `ingress.key`).
- Anidar `dynamic` dentro de `dynamic` es síntoma de datos mal estructurados: aplana con `flatten`.

## Limpieza

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate* out/
```

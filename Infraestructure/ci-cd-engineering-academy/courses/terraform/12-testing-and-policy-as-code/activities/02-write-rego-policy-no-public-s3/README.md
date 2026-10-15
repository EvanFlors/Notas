# Actividad 02 — Policy Rego: prohibir S3 público

## 1. Identificación

- **ID:** `tf-12-02-write-rego-policy-no-public-s3`
- **Tecnología:** `terraform`
- **Módulo:** `12-testing-and-policy-as-code`
- **Dificultad:** advanced
- **Duración estimada:** 60–120 min
- **Tipo:** independent

## 2. Contexto

Buckets S3 públicos son la causa #1 de brechas por misconfig de IaC en la industria. Esta actividad te hace **codificar** la política "ningún bucket público, nunca" como una regla Rego, y verificarla contra plans reales.

## 3. Objetivos

- Escribir `policy/s3.rego` con **al menos dos** reglas `deny`:
  1. Denegar `aws_s3_bucket_acl` con `acl ∈ { "public-read", "public-read-write" }`.
  2. Denegar la creación de un `aws_s3_bucket` **sin** un `aws_s3_bucket_public_access_block` asociado (BPA).
- Verificar la policy contra dos fixtures:
  - `tests/fixtures/plan-good.json` — bucket privado con BPA → **PASS**.
  - `tests/fixtures/plan-bad.json` — bucket público sin BPA → **FAIL**.
- Explicar por qué esta policy sobre `plan.json` es más robusta que la equivalente de checkov sobre HCL.

## 4. Prerrequisitos

- Haber completado `tf-12-01`.
- Opcional: `conftest` ≥ 0.46 instalado (el validador degrada con SKIP si falta y usa checks estructurales).
- Conocimiento de Rego a nivel intro (hay un refresher en `theory/lesson.md §8`).

**Costos**: ninguno.

## 5. Instrucciones

**No** mires `solution/` antes de intentarlo.

### 5.1 Explora los fixtures

```bash
cat tests/fixtures/plan-good.json | head -60
cat tests/fixtures/plan-bad.json  | head -60
```

Identifica, para cada bucket, los campos relevantes: `type`, `change.after.acl`, y la presencia (o no) de un `aws_s3_bucket_public_access_block`.

### 5.2 Escribe la policy

Crea `starter/policy/s3.rego` con `package main` (así `conftest` lo encuentra sin configurar). Pistas:

```rego
package main

# Regla 1 — ACL público prohibido.
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket_acl"
  # TODO: comparar r.change.after.acl contra la lista prohibida
  msg := sprintf("...", [r.address])
}

# Regla 2 — todo aws_s3_bucket debe tener un BPA asociado.
# Patron: coleccionar los bucket names, coleccionar los BPAs y su bucket referenciado,
# denegar los buckets sin BPA.
```

Pensá bien **qué correlacionar**. Un patrón útil:

```rego
bucket_names[name] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket"
  name := r.change.after.bucket
}

bpa_targets[name] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket_public_access_block"
  name := r.change.after.bucket
}

deny[msg] {
  bucket := bucket_names[_]
  not bpa_targets[bucket]
  msg := sprintf("bucket %q has no aws_s3_bucket_public_access_block", [bucket])
}
```

### 5.3 Verifica con conftest

```bash
cd starter
conftest test --policy policy/ ../tests/fixtures/plan-good.json  # 0 violaciones
conftest test --policy policy/ ../tests/fixtures/plan-bad.json   # ≥ 1 violacion, exit 1
```

### 5.4 Valida con el harness

```bash
cd ..
bash tests/validate.sh
```

## 6. Resultado esperado

- `starter/policy/s3.rego` existe.
- Contiene `package main`.
- Contiene al menos dos reglas `deny`.
- Menciona `public-read` y `aws_s3_bucket_public_access_block`.
- Si `conftest` está instalado: `plan-good.json` → 0 denies, `plan-bad.json` → ≥ 1 deny.

## 7. Criterios de aceptación

- [ ] Funcional: la policy diferencia `plan-good` (PASS) de `plan-bad` (FAIL).
- [ ] Cobertura: ambas reglas son necesarias (quitar una debe hacer pasar un caso que debería fallar).
- [ ] Calidad: `msg` describe la violación (incluye `address` o `bucket`).
- [ ] Mantenibilidad: policy en un solo archivo, `package` consistente, sin "magic strings" duplicadas.

## 8. Validación

```bash
bash tests/validate.sh
```

Dos modos:
- Con `conftest` instalado → ejecuta la policy contra ambos fixtures.
- Sin `conftest` → fallback estructural: grep de `package main`, `deny[`, `public-read`, `aws_s3_bucket_public_access_block` en `starter/policy/s3.rego`.

## 9. Preguntas de reflexión

1. ¿Por qué esta policy es más robusta sobre `plan.json` que si la escribieras en checkov sobre HCL? Da un caso concreto donde HCL diría "privado" y el plan diría "público".
2. ¿Qué pasa con un bucket cuyo nombre viene de `random_pet.suffix.id`? ¿Cómo lo evalúa Rego sobre el plan?
3. ¿Cómo escribirías la regla 2 si quisieras aceptar que el BPA venga de un **otro módulo** (p. ej. un módulo central de seguridad que crea BPAs para una lista de buckets por nombre)?
4. ¿Dónde pondrías esta policy en el pipeline: PR, merge o apply? Justifica.
5. ¿Qué diferencia hay entre `deny[msg]` y `violation[msg]`? ¿Y entre `deny` y `warn`? ¿Cuándo elegirías cada uno?

## 10. Extensiones

- **E1** — Añadir regla 3: denegar `aws_s3_bucket_policy` cuyo `Statement[].Principal` sea `"*"`.
- **E2** — Añadir una regla `warn` (no bloquea) para buckets sin tag `Owner`.
- **E3** — Convertir la policy en un paquete `terraform.aws.s3` y hacer que `conftest` lo encuentre con `--namespace terraform.aws.s3`.
- **E4** — Escribir tests de la policy en Rego mismo (`s3_test.rego` con `test_denies_public { ... }`) y correrlos con `opa test`.

## 11. Limpieza

```bash
rm -rf starter/.conftest-cache
```

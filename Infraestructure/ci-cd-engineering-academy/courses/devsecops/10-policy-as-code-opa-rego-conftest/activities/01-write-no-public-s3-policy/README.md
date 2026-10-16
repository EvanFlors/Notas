# Actividad 01 — Escribir y testear una policy "no public S3 bucket"

## 1. Identificación

- **ID:** `sec-10-01-write-no-public-s3-policy`
- **Tecnología:** `devsecops`
- **Módulo:** `10-policy-as-code-opa-rego-conftest`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Un buen porcentaje de brechas de datos de la última década se originó en un **S3 bucket público**: Capital One, Verizon, Dow Jones, FedEx, decenas más. En todos los casos la causa raíz fue la misma: *configuración por descuido* (acl `public-read`, policy abierta, `BlockPublicAcls: false`), no un atacante sofisticado.

En este ejercicio escribes la política que detecta esa clase entera de errores **antes** de que llegue a `terraform apply`. Rego + `opa test`.

## 3. Objetivos

Al terminar deberías:

- Escribir una regla `deny` que detecte los **tres** vectores clásicos de bucket público:
  1. `acl` en `{public-read, public-read-write}`.
  2. `aws_s3_bucket_public_access_block` con alguno de los 4 flags en `false`.
  3. Bucket policy con `Principal: "*"` sin `Condition`.
- Escribir **al menos 3 tests** `_test.rego`: un fixture bueno, dos malos.
- Entender por qué un bucket "privado" puede seguir siendo público via policy aunque la ACL sea correcta.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md`.
- Haber recorrido `examples/01` y `examples/03`.
- `opa` instalado (si no, el validador salta con gracia los chequeos funcionales y valida solo estructura).

**Costos:** ninguno. Todo offline.

## 5. Instrucciones

### 5.1 Preparar scratch

```bash
mkdir -p /tmp/sec-10-01-no-public-s3/policy
cd /tmp/sec-10-01-no-public-s3
```

### 5.2 Escribe `policy/s3.rego`

Crea el archivo con `package terraform.s3`, `import rego.v1`, y **al menos 2 bloques** `deny contains msg if { ... }` que detecten los vectores descritos en §3.

Esqueleto mínimo:

```rego
package terraform.s3

import rego.v1

# Vector 1: ACL público.
deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_s3_bucket"
    r.values.acl in {"public-read", "public-read-write"}
    msg := sprintf("S3 bucket %q has public ACL %q", [r.address, r.values.acl])
}

# Vector 2: public_access_block flojo. Completar.
# Vector 3: bucket policy con Principal "*" sin Condition. Completar.
```

### 5.3 Escribe `policy/s3_test.rego`

Crea tests en el mismo package. Mínimo **3 tests** (nombres que empiecen con `test_`). Debe incluir:

- Un test que asegura `count(deny) == 0` para un fixture bueno.
- Un test que asegura `some msg in deny` para un fixture con ACL público.
- Un test que asegura `count(deny) >= 1` para un fixture con `public_access_block` flojo.

### 5.4 Ejecuta la suite

```bash
opa test -v policy/
```

Debe salir **PASS: N/N** sin failures. Si `opa` no está, salta este paso — el validador detecta su ausencia.

### 5.5 Entregable

```
/tmp/sec-10-01-no-public-s3/
├── policy/
│   ├── s3.rego
│   └── s3_test.rego
└── NOTES.md     (opcional pero recomendado: 1 párrafo con las decisiones)
```

## 6. Resultado esperado

- `policy/s3.rego` contiene al menos **2** bloques `deny`.
- `policy/s3_test.rego` contiene al menos **3** reglas `test_*`.
- Si `opa` está disponible: `opa test policy/` sale sin failures.
- `bash tests/validate.sh /tmp/sec-10-01-no-public-s3` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: las policies detectan los fixtures malos del validador.
- **Calidad**: cada `deny` tiene un `msg` que explica *qué* y *dónde*.
- **Reproducibilidad**: `opa test` es determinista y rápido.
- **Mantenibilidad**: un paquete por dominio (`terraform.s3`), tests al lado.

## 8. Validación

```bash
bash <ruta-repo>/courses/devsecops/10-policy-as-code-opa-rego-conftest/activities/01-write-no-public-s3-policy/tests/validate.sh /tmp/sec-10-01-no-public-s3
```

El validador comprueba:

- Existencia de `policy/s3.rego` y `policy/s3_test.rego`.
- Que `s3.rego` tenga `package` + `import rego.v1` + ≥ 2 `deny`.
- Que `s3_test.rego` tenga ≥ 3 `test_*`.
- Si `opa` está disponible, corre `opa test` sobre la carpeta.

## 9. Preguntas de reflexión

1. ¿Por qué un bucket con `acl: private` puede seguir siendo público?
2. ¿Qué pasa si el `terraform plan` cambia la estructura (p. ej. nested modules)? ¿Tu regla sigue funcionando?
3. ¿Qué regla **falsamente positiva** probable tendrías contra equipos que legítimamente sirven assets públicos (CDN origin)?

## 10. Extensiones

- Añade **excepciones** por tag: si el bucket tiene `tags.public = "intentional"`, el `deny` del vector 1 no dispara.
- Añade una regla `warn` separada para "versioning disabled" (no `deny`, no debería bloquear).
- Convierte la policy a convención Conftest (`package main`, mismo contenido) y pruébala con `conftest test` sobre un `plan.json` sintético.

## 11. Limpieza

```bash
rm -rf /tmp/sec-10-01-no-public-s3
```

# Actividad 02 — Conftest "en CI" (wrapper local)

## 1. Identificación

- **ID:** `sec-10-02-conftest-in-ci`
- **Tecnología:** `devsecops`
- **Módulo:** `10-policy-as-code-opa-rego-conftest`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Que una política exista no sirve de nada si no se **ejecuta** en cada PR. Esta actividad simula localmente lo que un job de CI haría:

1. Partir de un directorio con **manifests K8s** y un **Terraform plan JSON** (fixtures incluidos).
2. Correr `conftest test` sobre ellos con un paquete de policies organizado.
3. Un script wrapper `run-conftest.sh` que:
   - sale con `exit 1` si hay cualquier `deny`.
   - imprime un resumen por archivo.
   - **salta con gracia** si `conftest` no está instalado (útil para CI que todavía no lo provisiona).

No se usa GitHub Actions real para que el ejercicio corra offline y determinista. El wrapper que escribes es equivalente al cuerpo de un step de Actions / GitLab CI.

## 3. Objetivos

Al terminar deberías:

- Organizar `policy/` en subpaquetes por dominio (`k8s/`, `terraform/`).
- Escribir un wrapper bash (`run-conftest.sh`) con `set -eu`, SKIP gracioso, resumen y exit code correcto.
- Entender el flag `--all-namespaces` y por qué es necesario cuando hay varios packages.
- Diferenciar `warn` de `deny` por efecto en el pipeline.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` (sobre todo §4, §6, §10).
- Haber recorrido `examples/02`.
- `conftest` instalado (opcional — el validador salta con gracia).

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Preparar scratch

```bash
mkdir -p /tmp/sec-10-02-conftest-ci/{inputs,policy/k8s,policy/terraform}
cd /tmp/sec-10-02-conftest-ci
```

### 5.2 Fixtures de input

Crea **dos** archivos en `inputs/`:

- `inputs/deployment.yaml` — un Deployment K8s con **una** violación (ej. imagen `:latest` o sin `resources.limits`).
- `inputs/plan.json` — un Terraform plan sintético con **una** violación (ej. SG `0.0.0.0/0`).

Puedes copiar los fixtures de los ejemplos `01` y `02` del módulo como punto de partida.

### 5.3 Policies

Crea **al menos dos** archivos de policy:

- `policy/k8s/deployment.rego` con `package k8s.deployment` + `import rego.v1` + al menos **1** `deny`.
- `policy/terraform/sg.rego` con `package terraform.sg` + `import rego.v1` + al menos **1** `deny`.

### 5.4 Wrapper `run-conftest.sh`

Crea `run-conftest.sh` en la raíz del directorio de trabajo. Debe:

1. `set -eu` (sin `pipefail`, por SIGPIPE — ver nota en el validador).
2. Si `conftest` **no está** en PATH, imprimir `SKIP: conftest not installed` y **salir con 0** (SKIP gracioso).
3. Correr `conftest test --all-namespaces --policy policy/ inputs/` (o equivalente).
4. Capturar el exit code real de conftest y propagarlo.
5. Imprimir un resumen al final (`== Conftest wrapper done ==`).

Hazlo ejecutable: `chmod +x run-conftest.sh`.

### 5.5 Ejecuta localmente

```bash
./run-conftest.sh
echo "exit=$?"
```

Esperado si `conftest` está instalado: exit code `1` (hay denies).

### 5.6 Entregable

```
/tmp/sec-10-02-conftest-ci/
├── inputs/
│   ├── deployment.yaml
│   └── plan.json
├── policy/
│   ├── k8s/deployment.rego
│   └── terraform/sg.rego
└── run-conftest.sh    (executable)
```

## 6. Resultado esperado

- Estructura y archivos descritos arriba existen.
- `run-conftest.sh` es ejecutable, tiene `set -eu`, maneja ausencia de `conftest` con SKIP, propaga exit code.
- Si `conftest` está disponible, al correr el wrapper se obtienen al menos **2** failures (uno por dominio).
- `bash tests/validate.sh /tmp/sec-10-02-conftest-ci` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: wrapper + policies + fixtures funcionan juntos.
- **Robustez**: SKIP gracioso cuando falta el binario.
- **Mantenibilidad**: paquetes separados por dominio.
- **Reproducibilidad**: cualquiera clona el starter y obtiene el mismo resultado.

## 8. Validación

```bash
bash <ruta-repo>/courses/devsecops/10-policy-as-code-opa-rego-conftest/activities/02-conftest-in-ci/tests/validate.sh /tmp/sec-10-02-conftest-ci
```

El validador comprueba:

- Estructura (`inputs/`, `policy/k8s/*.rego`, `policy/terraform/*.rego`).
- `run-conftest.sh` existe, tiene `set -eu` y maneja ausencia de `conftest`.
- Cada `.rego` tiene `import rego.v1` + al menos un `deny`.
- Si `conftest` está disponible, lo invoca y espera `exit 1` (al menos un deny).

## 9. Preguntas de reflexión

1. ¿Por qué `set -o pipefail` **no** se recomienda en wrappers con `grep -q`?
2. ¿Qué cambia si pones `warn` en vez de `deny`? ¿El wrapper puede distinguir ambos?
3. ¿Cómo evolucionarías el wrapper para producir **SARIF** y subirlo a GitHub Code Scanning?
4. ¿Cómo manejar excepciones por archivo (p. ej. "este manifest sí puede tener `:latest`")?

## 10. Extensiones

- Añadir un tercer paquete `policy/docker/` para validar un `Dockerfile` fixture.
- Añadir una regla `warn` separada y mostrar en el wrapper cuántos warn vs cuántos deny.
- Reescribir el wrapper como step de GitHub Actions (yaml) sin ejecutarlo — pura referencia.

## 11. Limpieza

```bash
rm -rf /tmp/sec-10-02-conftest-ci
```

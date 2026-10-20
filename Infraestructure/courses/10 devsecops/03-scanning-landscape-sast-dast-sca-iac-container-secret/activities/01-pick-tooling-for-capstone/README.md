# Actividad 01 — Elegir herramientas de scanning para el capstone

## 1. Identificación

- **ID:** `sec-03-01-pick-tooling-for-capstone`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-03-scanning-landscape-sast-dast-sca-iac-container-secret`
- **Dificultad:** beginner
- **Duración estimada:** 45–55 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Trabajas en una organización que acaba de aprobar DevSecOps y te pide **la matriz "capa × herramienta"** para integrar en el pipeline del capstone. El sistema es:

```
   repo:   mono-repo con app, Dockerfile multi-stage, charts Helm, Terraform para EKS
   app:    FastAPI (Python 3.12) + SQLAlchemy sobre Postgres RDS
   infra:  AWS (EKS, RDS, S3, ALB) desplegada por Terraform
   CI/CD:  GitHub Actions; publica imagen a GHCR; desplega con ArgoCD
   expuesto: ALB → ingress público; endpoint /api, /healthz, /metrics
```

**No hay que instalar nada**. El entregable es un documento Markdown con tu matriz y las justificaciones.

## 3. Objetivos

Al terminar deberías poder:

- Clasificar las 7 capas canónicas y asignar **una herramienta** por capa.
- Justificar cada elección citando: **qué categoría cubre**, **dónde corre** en el pipeline y **por qué** descartas 1–2 alternativas.
- Dibujar el pipeline con **gates ordenados** (shift-left max).
- Nombrar qué **no cubre** la matriz (lo que queda fuera del scope del módulo).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §2–§9 y §12).
- Haber recorrido los 3 `examples/` del módulo (sobre todo `01-scanning-matrix`).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-03-tooling
cd /tmp/sec-03-tooling
```

Puedes usar otro directorio pasándoselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `TOOLING.md` con tres secciones

#### Sección A — Matriz capa × herramienta

Rellena esta tabla con **al menos 6 capas** (6 de las 7 canónicas; el stack dado no es cloud-only, así que CSPM es opcional pero recomendado). Para cada una, decide la herramienta y justifica en 1–3 líneas.

```
## Matriz

| Capa                 | Herramienta elegida       | Punto de ejecución      | Justificación |
|----------------------|---------------------------|-------------------------|---------------|
| SAST (código Python) | Semgrep (+ ruleset flask) | pre-commit + PR         | ...           |
| SCA (deps Python)    | ...                       | ...                     | ...           |
| Secret scanning      | ...                       | ...                     | ...           |
| IaC (Terraform)      | ...                       | ...                     | ...           |
| IaC (Helm/K8s)       | ...                       | ...                     | ...           |
| Container (imagen)   | ...                       | ...                     | ...           |
| DAST (ALB público)   | ...                       | ...                     | ...           |
| CSPM (AWS)           | ...                       | ...                     | ...           |
```

Reglas:

- Nombra **la herramienta concreta** (`Semgrep`, `Trivy`, `Checkov`, `gitleaks`, `OWASP ZAP`, `Prowler`, etc.), no la categoría solo.
- La justificación debe citar al menos **una ventaja concreta** sobre una alternativa descartada.
- Al menos **una línea** debe mencionar `pre-commit` como punto de ejecución; al menos **una** debe mencionar `nightly`.

#### Sección B — Pipeline con gates

Dibuja (ASCII) el flujo pre-commit → PR → CI build → push → admisión → runtime, marcando **qué scanner corre en cada gate**.

Ejemplo (plantilla; **no la copies literal**, adáptala):

```
### Pipeline (gates shift-left max)

pre-commit:  gitleaks (quick), semgrep (ruleset basico), checkov (HCL quick)
                  │
                  ▼
PR check:    semgrep (full), trivy fs (SCA + secret), checkov (plan JSON)
                  │
                  ▼
CI build:    docker build; trivy image <img>; sarif → GH Code Scanning
                  │
                  ▼
registry:    push a GHCR; cosign sign (futuro: sec-09)
                  │
                  ▼
admision:    trivy operator en EKS; alerta si imagen vulnerable
                  │
                  ▼
nightly:     OWASP ZAP contra staging; prowler contra cuenta AWS
```

#### Sección C — Descartes y limitaciones

Lista al menos **3 descartes** explícitos ("elegí X y no Y porque…") y **2 cosas que esta matriz NO cubre**. Por ejemplo: "pentest manual", "runtime security (Falco — se verá en sec-12)", "revisión manual de código de seguridad".

### 5.3 Entregable

Un archivo:

```
/tmp/sec-03-tooling/TOOLING.md
```

con las tres secciones A, B y C.

## 6. Resultado esperado

- `TOOLING.md` existe y es coherente con el stack dado.
- La tabla cubre **al menos 6 capas** con herramienta y justificación.
- El pipeline cita **al menos 4 puntos de ejecución** distintos.
- La sección C tiene **al menos 3 descartes** justificados.
- `bash tests/validate.sh /tmp/sec-03-tooling` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada elección cita al menos una ventaja sobre una alternativa concreta.
- **Reproducibilidad**: alguien que lea tu documento puede dibujar el mismo pipeline sin dudar.
- **Mantenibilidad**: Markdown válido; tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-03-tooling
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho.

## 9. Preguntas de reflexión

1. Si tu stack añadiera **GraphQL** encima del REST, ¿cambiarías tu elección de DAST? ¿Por qué?
2. ¿Por qué correrías el IaC scanning **tanto sobre HCL** como **sobre el plan JSON** y no solo uno?
3. ¿Qué scanner te preocuparía **menos** desactivar temporalmente si todo el pipeline tarda demasiado? ¿Por qué?
4. ¿Cuál es el scanner que te resulta **más tentador omitir** y por qué sería un error?
5. Para la organización en el escenario, ¿preferirías Snyk (comercial, todo-en-uno) o la pila OSS (Trivy + Semgrep + gitleaks + Checkov)? Enumera 2 pros/contras de cada opción.

## 10. Extensiones

- Añade una fila con **SBOM generation** (Syft) — no es scanning estricto pero vive en el mismo gate.
- Dibuja un gate intermedio "preview environment" donde ZAP baseline corre contra una PR effímera.
- Añade una columna "owner" por capa (SAST → app team; CSPM → cloud ops; etc.).

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/sec-03-tooling
```

No hay procesos ni contenedores que detener.

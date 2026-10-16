# sec-10 — Lección: Policy as Code con OPA, Rego y Conftest

> 12 secciones. Local, sin cluster. Prerrequisito: `sec-07`.

---

## 1. El problema: políticas que viven en PDF

En la mayoría de organizaciones, las políticas de seguridad e infraestructura viven en **documentos**: un wiki de Confluence, un PDF del equipo de GRC, un canal de Slack con screenshots. Esto tiene cuatro problemas composables:

1. **No son ejecutables.** Nadie puede "correr" el PDF contra un pull request. La única manera de hacer cumplir la política es que una persona la recuerde y lo compruebe a mano.
2. **No son testeables.** No hay forma de garantizar que "ningún bucket S3 público" se cumple en los 400 módulos Terraform del monorepo, excepto hacer `grep` y rezar.
3. **No son versionables de verdad.** Un PDF se edita, pero no se puede revertir "esta frase" como se revierte una línea de código. Nadie hace code review a cambios de un wiki.
4. **Drift silencioso.** La política dice una cosa, el estado real del sistema dice otra, y nadie se entera hasta que hay incidente o auditoría.

**Policy as Code** ataca las cuatro: la política se escribe en un lenguaje formal (Rego), vive en un repo (versionada, revisable, con tests), y se **ejecuta** en cada PR y en cada apply.

> **Idea clave:** una política no vale lo que dice; vale lo que **impide**. Si no es ejecutable, es un deseo, no una política.

---

## 2. OPA: engine, no herramienta cerrada

**Open Policy Agent** (OPA) es un **engine de evaluación de políticas** escrito en Go, open source, graduado en la CNCF. Lo importante del adjetivo *engine*: OPA no sabe de Kubernetes, ni de Terraform, ni de HTTP. Sabe de **datos JSON** y de **reglas Rego** que operan sobre esos datos.

```
                 ┌──────────────────────────┐
   JSON input ──►│                          │
                 │        OPA engine        │─── decisión (bool / set / obj)
   Rego rules ──►│   (evaluates in memory)  │
                 │                          │
   JSON data  ──►│                          │
                 └──────────────────────────┘
```

Esto significa que OPA se **enchufa** a cualquier sistema que:

1. Sepa serializar su estado a JSON.
2. Sepa interpretar la decisión que OPA devuelve.

De ahí la variedad de integraciones reales:

- **Kubernetes** vía Gatekeeper (OPA detrás de un admission controller) o Styra DAS.
- **Terraform** vía `terraform plan -json` + Conftest.
- **CI/CD** (GitLab, Jenkins, ArgoCD) para autorizar deploys.
- **Microservicios** (Envoy, Istio) para decisiones de autorización HTTP vía `opa run` como sidecar.

Modos de uso de OPA:

| Modo | Comando | Caso |
|------|---------|------|
| **Evaluación puntual** | `opa eval` | "Dado este input + estas reglas, ¿qué devuelve?". Útil en scripts y debugging. |
| **Testing** | `opa test` | Correr `_test.rego` files. Es el modo que hace Rego *robusto*. |
| **Servidor HTTP** | `opa run --server` | OPA expone `/v1/data/<pkg>/<rule>`. Un microservicio pregunta decisiones por HTTP. Fuera de scope aquí. |
| **Linter** | `opa check`, `opa fmt` | Validar sintaxis y formatear reglas. |

---

## 3. Rego: lenguaje declarativo (una página)

Rego es **declarativo** y **funcional**. No describes *cómo* calcular algo, sino *qué condiciones* debe cumplir una decisión. Cada **regla** define una parte de un **documento virtual** llamado `data`.

### 3.1 Package e import

```rego
package k8s.security

import rego.v1
```

- `package` da el *path* bajo el cual la regla aparece en `data` (`data.k8s.security.<rule>`).
- `import rego.v1` activa la sintaxis moderna (OPA ≥ 0.59). Es la que usamos en este módulo.

### 3.2 Una regla `deny`

```rego
package k8s.security

import rego.v1

deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    not container.securityContext.runAsNonRoot
    msg := sprintf("container %q runs as root", [container.name])
}
```

Interpretación:

- `deny` es un **conjunto parcial** (`contains`). Cada evaluación que cumpla las condiciones **añade** un `msg` al conjunto.
- `if { ... }` lista las condiciones. **Todas** deben ser verdaderas (AND lógico implícito).
- `some container in input.spec.containers` **itera**. Si hay 3 containers, la regla se evalúa 3 veces y añade un `msg` por cada violación.
- `not X` es verdadero si X es falso o no existe (importante en Rego: ausencia = falso en contexto booleano).

### 3.3 Una regla `allow` (allow-list)

```rego
package k8s.security

import rego.v1

default allow := false

allow if {
    input.kind == "Pod"
    every container in input.spec.containers {
        container.securityContext.runAsNonRoot == true
    }
}
```

- `default allow := false` es imprescindible: sin un default, la ausencia de condiciones cumplidas deja la regla *undefined*, no falsa.
- `every` es el dual de `some`: **todos** los elementos deben cumplir.

### 3.4 Built-ins útiles para este módulo

| Built-in | Uso |
|----------|-----|
| `startswith(s, prefix)` | `startswith(image, "us-ecr.")` |
| `contains(s, substr)` | `contains(image, ":latest")` |
| `endswith(s, suffix)` | `endswith(image, ":latest")` |
| `regex.match(pattern, s)` | matches arbitrarios |
| `object.get(obj, key, default)` | lectura segura cuando una key puede faltar |
| `count(x)` | tamaño de array/set/object |
| `sprintf(fmt, args)` | mensajes de deny legibles |

### 3.5 Lo que **no** cubrimos

- `with` para mockear `input` o `data` en tests avanzados (lo usamos sólo en forma básica).
- Agregaciones complejas con `walk`.
- `partial evaluation` para optimización.
- Metadata annotations (`# METADATA`).

Esto es lo que necesitas para escribir reglas útiles de policy as code sobre IaC.

---

## 4. Conftest: Rego sin servidor, para YAML/JSON/HCL

**Conftest** es una CLI construida sobre OPA que:

1. Lee archivos **YAML**, **JSON**, **HCL** (Terraform), **Dockerfile**, **Cue**, **TOML**, **INI**.
2. Los convierte internamente a JSON.
3. Ejecuta las reglas Rego ubicadas por defecto en `./policy/` (configurable con `--policy`).
4. Agrega las violaciones y sale con `exit 1` si hay `deny`.

Convención de nombres **fija**:

| Nombre de regla | Severidad | Efecto en `conftest test` |
|-----------------|-----------|---------------------------|
| `deny[msg]` o `deny contains msg if {...}` | ERROR | `exit 1`, falla la build. |
| `warn[msg]` o `warn contains msg if {...}` | WARN | se imprime, **no** falla la build. |
| `violation[{"msg": ..., "details": ...}]` | ERROR estructurado | compatible con Gatekeeper. |

Esto es **convención**, no magia: Conftest literalmente busca reglas llamadas `deny`, `warn` y `violation` dentro del `package` que coincida con el input (o `main` por defecto).

### 4.1 Un ciclo típico

```bash
# Fixture a validar
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: app
          image: nginx:latest
EOF

# Política
cat > policy/deny_latest.rego <<'EOF'
package main
import rego.v1

deny contains msg if {
    input.kind == "Deployment"
    some c in input.spec.template.spec.containers
    endswith(c.image, ":latest")
    msg := sprintf("container %q uses :latest", [c.name])
}
EOF

conftest test deployment.yaml
# FAIL - container "app" uses :latest
# 1 test, 0 passed, 0 warnings, 1 failure
```

### 4.2 ¿Por qué Conftest y no OPA directo?

- **OPA directo** requiere construir el JSON de input a mano. Para un manifest K8s esto es trivial (ya es YAML → JSON); para un Terraform plan hay que correr `terraform show -json plan.out`; para un Dockerfile, parsearlo.
- **Conftest** absorbe esa conversión. Lee `.yaml`, `.tf`, `Dockerfile` directamente y presenta el input ya normalizado.

Regla práctica: **Conftest para IaC / configs; OPA directo (o server) para decisiones en runtime**.

---

## 5. Patrón `deny`: lista de violaciones

El patrón más común y más mantenible es **`deny` como conjunto parcial de mensajes**:

```rego
package k8s.security
import rego.v1

deny contains msg if {
    input.kind == "Pod"
    not input.spec.securityContext.runAsNonRoot
    msg := "pod spec is missing securityContext.runAsNonRoot=true"
}

deny contains msg if {
    input.kind == "Pod"
    some c in input.spec.containers
    endswith(c.image, ":latest")
    msg := sprintf("container %q uses forbidden :latest tag", [c.name])
}

deny contains msg if {
    input.kind == "Pod"
    some c in input.spec.containers
    not c.resources.limits.memory
    msg := sprintf("container %q has no memory limit", [c.name])
}
```

Ventajas:

- **Composición limpia**: cada regla es un chequeo independiente.
- **Mensajes propios**: cada violación trae su explicación — reduce "¿qué narices falló?".
- **Fácil de testear**: un `_test.rego` puede comprobar que un input concreto produce exactamente N denies con N mensajes esperados.

Compararlo con un `allow` monolítico:

```rego
# ANTIPATRÓN
default allow := false
allow if {
    input.kind == "Pod"
    input.spec.securityContext.runAsNonRoot
    every c in input.spec.containers {
        not endswith(c.image, ":latest")
        c.resources.limits.memory
    }
}
```

El `allow` monolítico te dice "no" sin decirte **por qué**. En producción, "no" sin motivo es inútil para el desarrollador que lo recibe.

---

## 6. `warn` vs `deny`: cuándo bajar la gravedad

Separar `warn` y `deny` permite introducir políticas sin romper el pipeline el día 1:

- **`warn`** — "esto no debería estar; arréglalo en el próximo PR". Útil para:
  - Migrar deuda técnica progresivamente.
  - Políticas nuevas que todavía no se han socializado.
  - Hallazgos de severidad media que no deben bloquear deploys.
- **`deny`** — "esto no puede entrar nunca". Reservado para:
  - Riesgo de seguridad explícito (secret en claro, bucket público).
  - Violación de compliance con auditoría (PCI, HIPAA, SOC2).
  - Costo potencial grande (p. ej. `t3.2xlarge` sin aprobación).

Estrategia de rollout típica:

1. Introducir la regla como `warn` 2–4 semanas.
2. Monitorear qué proyectos la generan y por qué.
3. Promover a `deny` cuando el ruido baje y los equipos tengan tiempo de corregir.

---

## 7. Testing de policies: `opa test` y `conftest verify`

Una política sin tests es exactamente igual de frágil que código sin tests. Rego tiene testing nativo.

### 7.1 Convención: archivos `_test.rego`

```
policy/
├── k8s_security.rego
└── k8s_security_test.rego
```

### 7.2 Un test

```rego
package k8s.security
import rego.v1

test_deny_latest_tag if {
    pod := {
        "kind": "Pod",
        "spec": {"containers": [{"name": "web", "image": "nginx:latest"}]}
    }
    some msg in deny with input as pod
    contains(msg, "latest")
}

test_allow_pinned_tag if {
    pod := {
        "kind": "Pod",
        "spec": {"containers": [{"name": "web", "image": "nginx:1.27.1"}]}
    }
    count(deny) == 0 with input as pod
}
```

- Toda regla cuyo nombre empieza con `test_` es un **test**.
- `with input as pod` **mockea** la variable `input` para esa evaluación. Es el mecanismo clave.
- El test pasa si **todas** sus condiciones son verdaderas (como cualquier regla Rego).

### 7.3 Ejecución

```bash
opa test -v policy/
# PASS: 2/2
```

o, para la convención Conftest (`main`):

```bash
conftest verify --policy policy/
```

### 7.4 Qué testear

- Un fixture **negativo** (el input viola la regla) → `count(deny) >= 1`.
- Un fixture **positivo** (el input cumple) → `count(deny) == 0`.
- Un fixture **de borde**: input vacío, campo opcional ausente, lista de 0 elementos.

Sin esto, cualquier refactor de una regla puede silenciosamente dejar de detectar lo que antes detectaba.

---

## 8. Excepciones: inevitables, pero con fecha

Toda política real tiene excepciones. Algunas legítimas (un bucket público de assets estáticos), otras acumuladas como deuda. El antipatrón es `# nosec` colgado del techo sin justificación ni expiración.

Patrón razonable: **lista de excepciones versionada en el mismo repo, con TTL y motivo**:

```rego
package k8s.security
import rego.v1

# Allow-list de pods permitidos a correr como root.
# Cada entrada debe tener motivo + expiración + owner.
# Al vencer, remover la entrada y auditar.
root_allowed_pods := {
    "legacy-nfs-mount-pod": {
        "reason": "legacy NFS mount, migration in progress",
        "owner": "platform@example.com",
        "expires": "2026-12-31"
    }
}

deny contains msg if {
    input.kind == "Pod"
    some c in input.spec.containers
    not c.securityContext.runAsNonRoot
    not input.metadata.name in object.keys(root_allowed_pods)
    msg := sprintf("container %q in pod %q runs as root", [c.name, input.metadata.name])
}
```

Lo importante no es el lenguaje de la excepción, sino que **esté en el repo, revisada por PR**, y que un job separado (fuera de scope aquí) alerte cuando `expires` esté vencido.

---

## 9. Organización de un paquete de policies

Para repos grandes, organizar por **dominio**:

```
policy/
├── k8s/
│   ├── security.rego
│   ├── security_test.rego
│   └── resources.rego
├── terraform/
│   ├── s3.rego
│   ├── s3_test.rego
│   ├── sg.rego
│   └── sg_test.rego
└── docker/
    └── base_images.rego
```

Reglas:

- Un `package` por archivo (`package k8s.security`, `package terraform.s3`).
- Tests al lado del código (`_test.rego`).
- `conftest` por defecto busca `./policy/`; el layout anterior funciona con `conftest test <files> --namespace k8s.security` o `--all-namespaces`.
- **Nunca** mezclar policies de distintos dominios en el mismo package: pierdes testeabilidad y claridad de mensajes.

---

## 10. Dónde ejecutar las policies

Policy as Code tiene 3 puntos de aplicación naturales, con trade-offs:

| Punto | Herramienta típica | Ventaja | Limitación |
|-------|-------------------|---------|------------|
| **Pre-commit** | `pre-commit` + `conftest` | Feedback instantáneo al dev | Lo puede saltar (`--no-verify`); solo lo que ve en local. |
| **CI / PR** | `conftest test` en GitHub Actions / GitLab CI | Fail de la build, enforce real, visible a reviewers | Depende de que el pipeline exista y se ejecute. |
| **Admission control** | Kyverno / OPA Gatekeeper (fuera de scope — `sec-11`) | **Última línea de defensa**, incluso contra `kubectl apply` manual | Latencia en admisión; policies tienen que ser rápidas. |

La respuesta madura es **los tres a la vez**, no uno u otro. Cada capa atrapa lo que las anteriores dejaron pasar.

---

## 11. Alternativas honestas

- **Checkov / tfsec / Terrascan** — scanners IaC "con batería incluida": vienen con cientos de reglas built-in. **Más rápido** para empezar, **menos flexible** cuando tu política es específica (p. ej. "todos los buckets deben tener la tag `cost_center`"). Buena combinación: scanners para lo genérico, Rego/Conftest para lo propio.
- **Sentinel** (HashiCorp) — lenguaje propietario de policy as code en Terraform Cloud/Enterprise. Potente pero **vendor-locked**; solo si ya pagas Terraform Cloud/Enterprise.
- **Cedar** (AWS) — lenguaje nuevo de policy as code; curva de aprendizaje distinta, ecosistema todavía pequeño comparado con Rego.
- **CUE** — más orientado a configuración + validación de schemas que a authorization pura; buen complemento, no competidor directo.

Regla práctica: para IaC **genérico**, Checkov/tfsec primero; para políticas **propias**, Rego + Conftest; para admission, Kyverno (si tu equipo es K8s-nativo) o Gatekeeper (si ya tienes expertise Rego).

---

## 12. Qué llevarse

Al terminar este módulo deberías:

- Escribir una regla `deny` con `some` o `every` en menos de 5 min.
- Escribir sus tests `_test.rego` sin consultar la documentación.
- Correr `opa test` y `conftest test` sobre fixtures locales y leer su salida.
- Decidir, para una política dada, si debe ser `warn` o `deny` y en qué punto del pipeline debe correr.
- Explicar por qué un PDF de política no cuenta como política.

Siguiente:

- `sec-11-k8s-admission-kyverno-and-policy-controller` — las mismas ideas, pero ejecutadas por el API server en el momento de admisión.

Síntesis en una línea:

> **Policy as Code convierte un documento en un programa: lo que antes se revisaba a ojo ahora falla el pipeline o no entra al cluster.**

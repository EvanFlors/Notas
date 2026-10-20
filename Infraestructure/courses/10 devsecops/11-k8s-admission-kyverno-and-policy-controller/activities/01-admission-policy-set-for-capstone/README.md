# Actividad 01 — Set de policies de admisión para el capstone

## 1. Identificación

- **ID:** `sec-11-01-admission-policy-set-for-capstone`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-11-k8s-admission-kyverno-and-policy-controller`
- **Dificultad:** advanced
- **Duración:** 60–90 min
- **Tipo:** independent (no depende de la actividad 02)

## 2. Contexto

El capstone del curso necesita un *baseline* de policies de admisión que todos los Pods de todos los namespaces (excepto `kube-system`) deben cumplir. Vas a construir ese baseline con **3 `ClusterPolicy` de Kyverno**, validarlas *offline* con `kyverno apply` y documentar el contrato en `POLICIES.md`.

No requiere cluster. Si tienes `kind` + `kubectl` puedes desplegarlo opcionalmente al final.

## 3. Objetivos

- Escribir 3 `ClusterPolicy` en YAML válido.
- Producir manifests buenos y malos que ejerciten cada regla.
- Testear *offline* con `kyverno apply` (si está disponible).
- Documentar el *set* en `POLICIES.md` explicando propósito, scope y modo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md`.
- Herramientas: `bash`, editor, idealmente `kyverno` CLI (opcional). `kind` + `kubectl` opcionales.
- **Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/sec-11-admission/{policies,manifests}
cd /tmp/sec-11-admission
```

### 5.2 Escribir las 3 policies

Crea bajo `policies/`:

- `01-require-labels.yaml` — `ClusterPolicy` que exige que todo Pod/Deployment/StatefulSet tenga labels `owner` y `app`.
- `02-disallow-latest-tag.yaml` — `ClusterPolicy` que prohíbe cualquier container (incluidos `initContainers`) con tag `:latest` o sin tag.
- `03-disallow-privileged.yaml` — `ClusterPolicy` que prohíbe `securityContext.privileged: true` en cualquier container.

Cada policy debe:

- Tener `validationFailureAction: Enforce` (o `Audit` si justificas en `POLICIES.md`).
- Excluir `kube-system`.
- Tener `message` humano en el bloque `validate`.

### 5.3 Escribir manifests de prueba

Crea bajo `manifests/`:

- `good-pod.yaml` — pasa las 3 policies.
- `bad-labels-pod.yaml` — viola `require-labels`.
- `bad-latest-pod.yaml` — viola `disallow-latest-tag`.
- `bad-privileged-pod.yaml` — viola `disallow-privileged`.

### 5.4 Documentar en `POLICIES.md`

Debe contener, como mínimo:

- Sección **Contrato** — qué exige el baseline, en qué namespaces, en qué modo.
- Sección **Rollout** — plan audit → enforce.
- Sección **Excepciones** — referencia a la actividad 02 (workflow).

### 5.5 Testear offline (si tienes kyverno-cli)

```bash
kyverno apply policies/ --resource manifests/
```

El validador *estructural* no requiere kyverno; si lo tienes instalado, lo invoca como bonus.

## 6. Entregable

```
/tmp/sec-11-admission/
├── POLICIES.md
├── policies/
│   ├── 01-require-labels.yaml
│   ├── 02-disallow-latest-tag.yaml
│   └── 03-disallow-privileged.yaml
└── manifests/
    ├── good-pod.yaml
    ├── bad-labels-pod.yaml
    ├── bad-latest-pod.yaml
    └── bad-privileged-pod.yaml
```

## 7. Validación

```bash
bash tests/validate.sh /tmp/sec-11-admission
```

El validador comprueba estructura (archivos, YAML parseable, campos clave). No evalúa semántica profunda — compárate con `solution/REFERENCE.md`.

## 8. Limpieza

```bash
rm -rf /tmp/sec-11-admission
```

Si usaste kind: `kind delete cluster --name sec11-act01`.

## 9. Preguntas de reflexión

1. ¿Qué política pondrías en `Audit` y cuál en `Enforce` el día 1, y por qué?
2. ¿Qué pasa si olvidas excluir `kube-system` y el webhook de Kyverno se cae?
3. ¿Podrías cubrir estas 3 reglas con VAP + CEL? ¿Qué ganarías y qué perderías?

# Actividad 02 — Deploy de Backstage en K8s vía chart Helm oficial

## 1. Identificación

- **ID:** `plat-04-02-k8s-deploy-via-helm`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-04-backstage-architecture-and-setup`
- **Dificultad:** intermediate
- **Duración estimada:** 60–90 min
- **Tipo:** independent

## 2. Contexto

Esta actividad traduce lo aprendido sobre arquitectura a un **deploy real** en Kubernetes usando el chart oficial de la comunidad (`backstage/backstage` del repo `backstage/charts`). El entregable combina **documentación operativa** (`HELM-DEPLOY.md`) y un **artefacto ejecutable** (`values.yaml`).

> **Tooling:** `helm` opcional. Si lo tienes, el validador intenta `helm template` para validar el YAML. Si no, hace **SKIP** limpio y se queda con la verificación estructural de que el `values.yaml` es YAML válido y contiene los bloques esperados.

## 3. Objetivos

- Preparar un `values.yaml` real con `image`, `extraEnvVars` (secretos via `secretKeyRef`), `ingress` TLS, Postgres externo.
- Documentar la cadena de secretos (OAuth GitHub + Postgres) sin pegar valores reales.
- Argumentar `postgresql.enabled=false` + managed PG en prod.
- Nombrar al menos 5 bloques críticos y justificar cada uno.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §8.
- Haber completado la actividad 01 (recomendado, no obligatorio — son independientes).
- `bash` y editor. **Opcional:** `helm` para validar el chart.

**Costos:** cero (no se crea cluster).

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/plat-04-helm
cd /tmp/plat-04-helm
```

### 5.2 Producir `values.yaml`

Crea `/tmp/plat-04-helm/values.yaml` con **al menos** los bloques:

1. `backstage.image` (registry, repository, tag).
2. `backstage.extraEnvVars` con `secretKeyRef` para `POSTGRES_*` y `AUTH_GITHUB_*`.
3. `ingress` habilitado con TLS.
4. `postgresql.enabled: false` (vamos a usar PG externo managed).
5. (Opcional pero recomendado) `serviceMonitor.enabled: true`.

**Prohibido** pegar secretos reales. Las referencias a secretos van vía `secretKeyRef` apuntando a Secrets de K8s que se crean por fuera (External Secrets Operator / Vault / SOPS).

### 5.3 Producir `HELM-DEPLOY.md`

Crea `/tmp/plat-04-helm/HELM-DEPLOY.md` con las **cuatro secciones** siguientes. Los headings deben empezar con `## Seccion <letra>`.

#### Sección A — Instalación del chart

- Comandos `helm repo add backstage https://backstage.github.io/charts` + `helm install`.
- Namespace de destino.
- Flags clave (`--values`, `--create-namespace`).

#### Sección B — Anatomía del `values.yaml`

- Enumerar los 5+ bloques críticos.
- Para cada uno: qué controla y por qué.

#### Sección C — Cadena de secretos

- Diagrama o lista: External Secrets Operator → Secret `backstage-pg` + `backstage-gh` → `secretKeyRef` en `extraEnvVars` → env en el container.
- Nota explícita de **cero secretos reales**; todo via referencias.

#### Sección D — Decisiones productivas

- `postgresql.enabled=false` + managed PG: por qué.
- `ingress.tls` obligatorio: por qué (GitHub OAuth exige HTTPS en dominio público).
- Observabilidad: `serviceMonitor` + logs estructurados + traces.
- Política de upgrade (`helm upgrade` + leer release notes del chart).

### 5.4 Entregables

```
/tmp/plat-04-helm/values.yaml
/tmp/plat-04-helm/HELM-DEPLOY.md
```

### 5.5 Limpieza

```bash
rm -rf /tmp/plat-04-helm
```

## 6. Resultado esperado

- `values.yaml` es YAML válido y contiene los bloques requeridos.
- `HELM-DEPLOY.md` tiene las 4 secciones.
- **Ningún secreto literal** — todo vía `secretKeyRef` o `${VAR}`.
- `bash tests/validate.sh /tmp/plat-04-helm` sale en verde (los pasos con `helm` pueden salir SKIP si no está instalado).

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctness**: `helm template` (si está disponible) renderiza sin error.
- **Seguridad**: cero secretos reales.
- **Reproducibilidad**: el mismo `values.yaml` + `helm install` lleva al mismo deploy.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-04-helm
```

El validador:

- Comprueba estructura de ambos archivos.
- Verifica que `values.yaml` parsee como YAML (con `python3 -c 'import yaml'`).
- Si `helm` está disponible, intenta `helm template`.
- Verifica ausencia de secretos tipo `ghp_` reales fuera de placeholders.

## 9. Preguntas de reflexión

1. ¿Por qué `postgresql.enabled=true` del subchart es útil para demos pero inaceptable para prod?
2. Si tu equipo no tiene External Secrets Operator, ¿qué alternativas tienes para inyectar los secrets de GitHub OAuth?
3. ¿Qué pasa si tu Ingress sirve HTTP y configuraste la callback URL de GitHub en HTTPS?
4. ¿Qué upgradearías primero: el chart o el framework Backstage? ¿Por qué?
5. ¿Cuándo preferirías Kustomize puro (sin Helm) para desplegar Backstage?

## 10. Extensiones

- Añade un `NetworkPolicy` denegando egress excepto a Postgres + GitHub.
- Añade `podDisruptionBudget` con `minAvailable: 1`.
- Documenta el chart de `postgresql` oficial (bitnami) como alternativa para dev pero no prod.

## 11. Autoevaluación

Compara con `solution/REFERENCE.md` y `solution/values.yaml`.

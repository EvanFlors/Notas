# Actividad 02 — Verifica un chart firmado en otro entorno

## 1. Identificación

- **ID:** `helm-08-02-verify-in-another-env`
- **Tecnología:** `helm`
- **Módulo:** `08-repositories-oci-and-provenance`
- **Dificultad:** advanced
- **Duración estimada:** 45 min
- **Tipo:** independent

## 2. Contexto

Eres **otro equipo** (otro cluster, otra org, otro humano). Alguien publicó un chart firmado y te dice: "úsalo". Antes de instalarlo en producción tienes que probar, **sin confiar** en el publisher, que:

1. El chart existe y es consumible desde tu entorno limpio.
2. La firma criptográfica es válida.
3. La identidad / clave con la que se firmó corresponde a lo que esperas (no a *cualquier* firma válida).
4. El chart puede renderizarse e instalarse (modo dry-run) **air-gap** desde el `.tgz` descargado.

Este es el flujo real de un *consumer* enterprise. No se te da un script "paso a paso": se te da el input (una referencia OCI + una pública o una identidad OIDC) y tienes que diseñar la validación.

## 3. Objetivos

Al terminar deberías poder:

- Pullear un chart desde un registry OCI (local o GHCR) a un entorno nuevo sin credenciales previas (si es público) o con credenciales mínimas (si es privado).
- Verificar la firma cosign del chart por digest.
- Hacer `helm template` / `helm install --dry-run` desde el `.tgz` local, sin volver a la red.
- Argumentar la diferencia entre "firma criptográficamente válida" y "firma válida *y* legítima".

## 4. Prerrequisitos

- Helm ≥ 3.11, cosign ≥ 2.0.
- Un chart firmado publicado — típicamente el que acabas de hacer en `activities/01`. Si no lo tienes, corre primero `activities/01/solution/run-solution.sh` para preparar el entorno (`MODE=local`).
- Costos: ninguno.

### Variables de entorno que define esta actividad

| Variable | Significado | Default (local) |
|----------|-------------|------------------|
| `MODE` | `local` o `live` | `local` |
| `BASE` | workdir del consumer | `/tmp/helm-08-act02` |
| `CHART_REF` | referencia OCI al chart | `oci://localhost:5000/charts/mi-app` |
| `CHART_VERSION` | versión a verificar | `0.1.0` |
| `COSIGN_PUB` | path a cosign.pub (modo key-based) | `/tmp/helm-08-act01/keys/cosign.pub` |
| `COSIGN_IDENTITY_REGEX` | regex de identidad OIDC (modo keyless) | *(unset en local)* |
| `COSIGN_OIDC_ISSUER` | issuer OIDC (modo keyless) | *(unset en local)* |

## 5. Instrucciones

**No hay solución paso a paso.** La actividad evalúa que diseñes el flujo. Entregables:

1. Prepara un **workspace limpio** en `/tmp/helm-08-act02/` (NO reuses el de la actividad 01 — ese es "el publisher").
2. Diseña y ejecuta la **verificación**:
   - Resuelve el **digest** del chart (vía API HTTP del registry *o* `helm show chart` según tu helm).
   - Haz `cosign verify` por digest, con la pública correspondiente *o* con los flags de keyless (`--certificate-identity-regexp` + `--certificate-oidc-issuer`).
   - Haz al menos **una prueba negativa**: verifica con la pública/identidad *incorrecta* y confirma que falla.
3. Diseña y ejecuta la **operación air-gapped**:
   - `helm pull` el chart a tu workspace.
   - `helm template` desde el `.tgz` local → captura la salida.
   - `helm install --dry-run` desde el `.tgz` local.
4. **Documenta** en `/tmp/helm-08-act02/REPORT.md` qué garantías obtuviste y, crítico: ¿la firma válida que viste prueba *qué* exactamente? (Pista: una firma válida con clave `X` solo prueba "esto lo firmó quien tenía `X`". Que `X` sea *legítima* es otro problema, resuelto por la cadena OIDC + policy en keyless, o por confianza en el canal donde recibiste la pública en key-based.)

## 6. Resultado esperado

- Workspace `/tmp/helm-08-act02/` con:
  - `pulled/<chart>-<version>.tgz`
  - `rendered.yaml` (output de `helm template`)
  - `REPORT.md` (tu análisis — mínimo 10 líneas).
- La ejecución documenta: verificación positiva OK, verificación negativa FAIL, template exitoso desde el `.tgz`.

## 7. Criterios de aceptación

- `tests/validate.sh` sale con código 0.
- El `.tgz` se verificó **por digest**, no por tag.
- La prueba negativa está presente y realmente falla.
- `REPORT.md` existe y responde la pregunta de "¿qué prueba una firma válida?".
- No se ejecutó ningún comando que *contactara al publisher* más allá del pull inicial (prueba de independencia).

## 8. Validación

```bash
# Si tu chart está en el default local (del lab 01):
bash tests/validate.sh

# Si usaste un chart distinto / live:
CHART_REF=oci://ghcr.io/yourorg/charts/mi-app \
CHART_VERSION=0.1.0 \
COSIGN_PUB=/path/to/cosign.pub \
bash tests/validate.sh
```

El script comprueba:

1. Existe `pulled/<chart>-<version>.tgz` en `BASE`.
2. `cosign verify` con `COSIGN_PUB` (o keyless) pasa.
3. Una verificación con pública fresca falla (prueba negativa automática).
4. `helm template` desde el `.tgz` produce manifests válidos (no vacío, no error).
5. Existe `REPORT.md` con contenido no trivial.

## 9. Preguntas de reflexión

1. "Firma válida" ≠ "firma legítima". Explica la diferencia con un ejemplo concreto de supply chain attack donde una firma válida no te protege.
2. En keyless, ¿qué pasa si tu `--certificate-identity-regexp` es demasiado laxo (p. ej. `.*`)? ¿Qué atacante exploita eso?
3. Si el chart tuviera `dependencies:` apuntando a otro OCI remoto, ¿bastaría con haber hecho `helm pull` del chart principal para operar air-gap? ¿Qué comando habría tenido que correr el publisher?
4. Compara el esfuerzo operativo de rotar la pública cosign (key-based) vs. rotar la identidad OIDC permitida (keyless). ¿Cuál escala mejor en una org de 100 microservicios?
5. ¿Cómo integrarías esta verificación en un **admission controller** del cluster para que ningún release se cree con un chart no firmado?

## 10. Extensiones

- Mete la verificación en un `pre-install` hook de un pipeline (GHA step) que falle el deploy si la firma no corresponde.
- Reproduce el flujo contra un chart **real** firmado (por ejemplo `cert-manager`, `argo-cd`): investiga qué firma publican y con qué identidad OIDC verificarías.
- Escribe una `Kyverno` o `Cosign Policy Controller` policy que rechace charts sin firma de una identidad específica (research, no implementation obligatoria).

## 11. Limpieza

```bash
rm -rf /tmp/helm-08-act02
```

El publisher (`/tmp/helm-08-act01` + registry local) se limpia según las instrucciones de la actividad 01.

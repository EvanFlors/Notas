# Actividad 02 — Diagnosticar un `Application` `OutOfSync`

## 1. Identificación

- **ID:** `argo-03-02-diagnose-out-of-sync`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `argo-03-application-anatomy-sources-destinations-sync`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** independent / debug

## 2. Contexto

Recibes el repo de infra con **tres `Application` manifests reales**, todas en estado `OutOfSync` por razones distintas. Tu trabajo es el que harías un lunes por la mañana en producción: diagnosticar, documentar causa raíz, y proponer la corrección mínima.

Las tres causas pertenecen al top de la lección (`theory/lesson.md` §12.1):

- **Scenario A** — `targetRevision` apunta a algo que *se mueve* y nadie lo sabe.
- **Scenario B** — hay un HPA real escribiendo `replicas`; el `Application` no lo contempla y Argo CD lo pelea.
- **Scenario C** — alguien hizo un `kubectl edit` en el cluster (política ad-hoc durante un incidente); el repo sigue en el estado anterior.

Esta actividad es **independiente**: nadie te da la respuesta. Debes:

1. Ejecutar `starter/build-scenarios.sh` que genera los tres escenarios en `/tmp/argo-03-02/`.
2. Leer los manifiestos y la "evidencia operativa" (archivos `evidence.md` y estados simulados).
3. Escribir tu diagnóstico en `report.md` siguiendo la plantilla.
4. Aplicar la **corrección mínima** editando los manifiestos (o el archivo de "estado del cluster" cuando aplique) en los directorios `scenario-?/`.
5. Validar con `bash tests/validate.sh`.

**Pista honesta**: la lección cubre las tres causas. Esto es diagnóstico, no investigación nueva.

## 3. Objetivos

Al terminar deberías poder:

- Reconocer rápidamente las tres causas más frecuentes de `OutOfSync`.
- Elegir la corrección correcta por causa:
  - A → cambiar `targetRevision` a una ref apropiada (branch estable, tag, commit).
  - B → añadir `ignoreDifferences` sobre `/spec/replicas` + `RespectIgnoreDifferences=true`.
  - C → o bien promover el cambio manual a Git (si fue correcto), o bien revertir el cluster.
- Documentar la causa raíz en una línea.

## 4. Prerrequisitos

- Haber hecho la actividad 01 del módulo.
- `kubectl`, `bash`, `grep`, `sed` instalados.
- Opcional: `kind` + Argo CD. **No requeridos**: todo lo observable se simula vía archivos.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Construir los escenarios

```bash
cd courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/activities/02-diagnose-out-of-sync
bash starter/build-scenarios.sh
```

Esto crea `/tmp/argo-03-02/scenario-a/`, `/scenario-b/`, `/scenario-c/`.

Cada carpeta contiene:

- `application.yaml` — el `Application` CR tal como está hoy.
- `desired-in-git.yaml` — lo que el `repo-server` renderizaría (el "desired state" según el repo).
- `live-in-cluster.yaml` — lo que un `kubectl get -o yaml` traería del cluster (el "live state" simulado).
- `evidence.md` — notas operativas: últimos commits del repo, salida de `argocd app diff`, alertas en el canal.
- `report.md` — plantilla donde tú escribirás el diagnóstico y la corrección.

### 5.2 Diagnosticar cada escenario

Para cada `scenario-?/`:

1. Lee `application.yaml`, `desired-in-git.yaml`, `live-in-cluster.yaml`, `evidence.md`.
2. Formula una hipótesis **antes** de ver el próximo escenario.
3. Escribe en `report.md`:
   - **Causa raíz (una línea).**
   - **Corrección mínima aplicada (uno o dos bullets).**
   - **Riesgo si no se corrige.**

### 5.3 Aplicar la corrección mínima

Depende del escenario. Opciones típicas:

- **Scenario A** — editar `application.yaml` para cambiar `targetRevision`.
- **Scenario B** — editar `application.yaml` para añadir `ignoreDifferences` y `RespectIgnoreDifferences=true`.
- **Scenario C** — editar `desired-in-git.yaml` (promover el cambio a Git) *o* editar `live-in-cluster.yaml` (revertir el cluster). Elige y justifica.

Deja los archivos editados en el *mismo* `scenario-?/` donde los encontraste.

### 5.4 Validar

```bash
bash tests/validate.sh
```

Debe terminar en `OK` cuando los tres escenarios estén diagnosticados y corregidos.

## 6. Resultado esperado

- `/tmp/argo-03-02/scenario-a/report.md`, `scenario-b/report.md`, `scenario-c/report.md` completos (sin `TODO`).
- Correcciones aplicadas en los manifiestos de cada escenario.
- `tests/validate.sh` termina con `OK` y la cuenta de 3/3.

## 7. Criterios de aceptación

- [ ] Para A: `targetRevision` ya no apunta a `HEAD` ni a un branch volátil.
- [ ] Para B: el `Application` incluye `ignoreDifferences` para `/spec/replicas` en el Deployment en cuestión **y** `RespectIgnoreDifferences=true` en `syncOptions`.
- [ ] Para C: desired y live concuerdan (al promover a Git o al revertir en cluster) y la decisión está justificada en `report.md`.
- [ ] Los tres `report.md` tienen causa raíz escrita en una línea.
- [ ] `validate.sh` termina en `OK`.

## 8. Validación

```bash
bash courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/activities/02-diagnose-out-of-sync/tests/validate.sh
```

El validador comprueba:

- Para A: `targetRevision` final no es `HEAD`.
- Para B: aparecen `ignoreDifferences` sobre `/spec/replicas` *y* `RespectIgnoreDifferences=true`.
- Para C: `desired-in-git.yaml` y `live-in-cluster.yaml` ya no difieren en el campo clave.
- Cada `report.md` existe, no tiene `TODO:` restante y tiene al menos una línea no vacía bajo "Causa raíz".

## 9. Preguntas de reflexión

1. En el Scenario A, ¿por qué el cambio *no fue detectado* por nadie hasta que algo falló? ¿Qué proceso ayudaría a prevenir?
2. En el Scenario B, ¿qué pasa en el *primer* ciclo de reconciliación tras aplicar tu corrección? ¿Y en los siguientes?
3. En el Scenario C, ¿bajo qué condiciones es correcto *promover* el cambio manual a Git en lugar de revertir? ¿Y al revés?
4. Para los tres escenarios, ¿qué alerta operativa habrías querido tener (notifications-controller) para enterarte antes?
5. Si tu organización no quiere `selfHeal: true` en producción, ¿cómo cambiaría tu respuesta al Scenario C?

## 10. Extensiones (opcional)

- **E1** — Diseña un **Scenario D**: un `Application` con `destination.namespace` distinto al `metadata.namespace` de los recursos del repo. Construye los tres YAML y la plantilla; súmalo a `build-scenarios.sh` y a `validate.sh`.
- **E2** — Si tienes Argo CD corriendo: reproduce el Scenario B creando un Deployment + HPA en un cluster `kind` y observa el pingpong real en la UI antes de aplicar la corrección.
- **E3** — Escribe una política OPA/Kyverno que impida que un `Application` tenga `targetRevision: HEAD`.

## 11. Limpieza

```bash
rm -rf /tmp/argo-03-02
```

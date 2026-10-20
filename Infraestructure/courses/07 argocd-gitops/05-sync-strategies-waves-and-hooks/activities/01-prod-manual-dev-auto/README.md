# Actividad 01 — Políticas de sync diferenciadas: prod manual, dev automated

## 1. Identificación

- **ID:** `argo-05-01-prod-manual-dev-auto`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `05-sync-strategies-waves-and-hooks`
- **Dificultad:** intermediate
- **Duración estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto

En producción, auto-sync + `selfHeal` activo durante un incidente puede ser peligroso: un operador haciendo `kubectl scale` para contener fuego verá cómo Argo CD revierte el cambio en segundos. En dev, por el contrario, auto-sync + prune + selfHeal es exactamente lo que quieres para no perder tiempo pulsando botones.

El `starter/` contiene:

- `apps/web-dev.yaml` — `Application` sin `syncPolicy` definida.
- `apps/web-prod.yaml` — `Application` sin `syncPolicy` definida.
- `projects/prod.yaml` — `AppProject` `prod` sin `syncWindows`.

Tu tarea: configurar las políticas correctas en cada manifest para que:

- **`web-dev`** sincronice automáticamente con `prune`, `selfHeal`, `CreateNamespace=true`, `ServerSideApply=true` y `retry` razonable.
- **`web-prod`** quede **sin `syncPolicy.automated`** (sync manual) pero con `syncOptions` incluyendo al menos `ServerSideApply=true` y `PruneLast=true`.
- **`AppProject prod`** incluya al menos **un sync window `deny` 24/7** que puede ser superado manualmente (`manualSync: true`) — simula "deploys solo por approval explícito".

## 3. Objetivos

- Diferenciar `syncPolicy` por entorno con criterio justificable.
- Añadir sync window `deny` con `manualSync: true` a un `AppProject`.
- Validar los manifests con `kubectl apply --dry-run=server` (si hay cluster) y con el validador local provisto.

## 4. Prerrequisitos

- `kubectl` instalado.
- `yq` o similar NO es necesario (el validador usa herramientas estándar y Python 3 si está disponible).
- Un cluster `kind` **opcional**: si no está disponible, el validador saltará los checks de API y validará solo los manifests sintácticamente.
- Argo CD **opcional**: si no está instalado, el validador no intentará aplicar los recursos; solo validará el YAML.
- Sin costos (todo local).

## 5. Instrucciones

1. **Preparar el directorio de trabajo:**

   ```sh
   mkdir -p /tmp/argo05-act01
   cp -r starter/* /tmp/argo05-act01/
   cd /tmp/argo05-act01
   ```

2. **Editar `apps/web-dev.yaml`:**
   - Añadir `spec.syncPolicy.automated` con `prune: true`, `selfHeal: true`, `allowEmpty: false`.
   - Añadir `spec.syncPolicy.syncOptions` con `CreateNamespace=true`, `ServerSideApply=true`, `ApplyOutOfSyncOnly=true`.
   - Añadir `spec.syncPolicy.retry` con `limit: 5` y `backoff` (`duration: 5s`, `factor: 2`, `maxDuration: 3m`).

3. **Editar `apps/web-prod.yaml`:**
   - **NO** añadir `automated`.
   - Añadir `spec.syncPolicy.syncOptions` con al menos `ServerSideApply=true` y `PruneLast=true`.
   - `retry` opcional pero recomendado con límite más bajo (p. ej. `limit: 2`).

4. **Editar `projects/prod.yaml`:**
   - Añadir `spec.syncWindows` con al menos **una entrada** `kind: deny`, `schedule: "* * * * *"`, `duration: 24h`, `applications: ["web-prod"]`, `manualSync: true`.

5. **Validar:**

   ```sh
   bash <ruta-a-esta-actividad>/tests/validate.sh /tmp/argo05-act01
   ```

6. **(Opcional) Aplicar a un cluster con Argo CD:**

   ```sh
   kubectl apply -n argocd -f /tmp/argo05-act01/projects/prod.yaml
   kubectl apply -n argocd -f /tmp/argo05-act01/apps/
   argocd app list
   ```

## 6. Resultado esperado

- `apps/web-dev.yaml` incluye `syncPolicy.automated.{prune,selfHeal}: true`.
- `apps/web-prod.yaml` **NO** incluye `syncPolicy.automated`, pero sí `syncOptions` con `ServerSideApply=true` y `PruneLast=true`.
- `projects/prod.yaml` tiene al menos una `syncWindow` `deny` con `manualSync: true`.
- Validador reporta `RESULT: 7/7 OK` (o más, si añades checks extra).

## 7. Criterios de aceptación

- **Funcional:** los tres manifests son YAML válidos (parsean con PyYAML).
- **Operativo:** las policies responden al patrón descrito en teoría §10.
- **Documental:** el estudiante puede explicar en una frase por qué `selfHeal` está off en prod.

## 8. Validación

```sh
bash tests/validate.sh /tmp/argo05-act01
```

El validador:
- Comprueba que los tres archivos existen y parsean como YAML.
- Comprueba la `syncPolicy` de cada Application.
- Comprueba la presencia del sync window `deny` en el `AppProject prod`.
- SKIP de los checks que requieren cluster/Argo CD si no están disponibles.

## 9. Preguntas de reflexión

- ¿Qué pasa si olvidaras `manualSync: true` en el sync window `deny`? ¿Cómo haces un hotfix urgente?
- ¿Por qué `PruneLast=true` tiene sentido especialmente en prod y no tanto en dev?
- `selfHeal: true` en stg — pros y contras según tu equipo QA.
- Si Argo CD cae y los manifests cambian en Git mientras tanto, ¿qué pasa cuando vuelve? ¿Es diferente en dev vs prod con esta config?

## 10. Extensiones

- Añadir una segunda `syncWindow` `allow` para martes 10:00 UTC de 2h con `manualSync: false` (deploys automáticos solo en esa ventana).
- Añadir `spec.ignoreDifferences` a `web-prod` para `replicas` del `Deployment` (convive con HPA).
- Escribir una ADR corta (≤ 1 página) justificando el patrón por entorno.

## 11. Limpieza

```sh
# Si aplicaste a un cluster:
kubectl delete -n argocd -f /tmp/argo05-act01/apps/ --ignore-not-found
kubectl delete -n argocd -f /tmp/argo05-act01/projects/prod.yaml --ignore-not-found
# Siempre:
rm -rf /tmp/argo05-act01
```

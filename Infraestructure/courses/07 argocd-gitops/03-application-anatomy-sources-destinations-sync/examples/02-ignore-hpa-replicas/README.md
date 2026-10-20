# Ejemplo 02 — `ignoreDifferences` para `replicas` cuando hay HPA

## Concepto que demuestra

Por qué un `Deployment` con HPA causa drift continuo si Argo CD gestiona `replicas`, y cómo `spec.ignoreDifferences` (más `RespectIgnoreDifferences=true`) lo resuelve limpiamente.

## Contexto

Escenario clásico:

1. En Git tienes `Deployment.spec.replicas: 3`.
2. El cluster tiene un `HorizontalPodAutoscaler` que puede subir a 10.
3. El HPA observa carga alta y sube `replicas` a 7.
4. Argo CD compara: "repo dice 3, cluster dice 7 → OutOfSync".
5. Con `selfHeal: true`, Argo CD aplica `replicas: 3`.
6. HPA vuelve a subir.
7. Loop infinito. Usuarios enfadados.

La solución es decirle a Argo CD "ignora `/spec/replicas` en este Deployment — no es mío".

## Prerrequisitos

- `kubectl` instalado.
- `jq` instalado (para parsear YAML en el walkthrough).
- Opcional: cluster `kind` + Argo CD para una demo end-to-end (no requerida para entender el patrón).

## Archivos

- `deployment-with-hpa.yaml` — `Deployment` + `HPA` de ejemplo.
- `application-wrong.yaml` — `Application` **sin** `ignoreDifferences` (muestra el pitfall).
- `application-correct.yaml` — `Application` **con** `ignoreDifferences` y `RespectIgnoreDifferences=true` (correcto).
- `demo.sh` — compara los dos manifiestos y resalta la diferencia, validando sintaxis.

## Ejecución

```bash
cd courses/argocd-gitops/03-application-anatomy-sources-destinations-sync/examples/02-ignore-hpa-replicas
bash demo.sh
```

## Resultado esperado

- `demo.sh` imprime el diff estructural entre los dos Applications.
- Resalta el bloque `ignoreDifferences` y el syncOption `RespectIgnoreDifferences=true`.
- Valida ambos manifiestos client-side.

## Interpretación

Lo clave son **dos** cosas, no una:

1. `ignoreDifferences: [{group: apps, kind: Deployment, jsonPointers: [/spec/replicas]}]` — le dice a Argo CD "ignora este campo al calcular el diff".
2. `syncOptions: [RespectIgnoreDifferences=true]` — le dice a Argo CD "ignora también al hacer `apply`". **Sin esto, el pitfall persiste**: el diff no reportaría drift pero el apply seguiría sobreescribiendo `replicas: 3`.

El patrón funciona con JSON Pointer (RFC 6901) para rutas simples y con `jqPathExpressions` cuando necesitas selectores más potentes (p. ej. "todos los `resources` de todos los containers").

## Errores frecuentes

- **Añadir `ignoreDifferences` pero olvidar `RespectIgnoreDifferences=true`** — el bug sigue ocurriendo. Es *el* pitfall de este patrón.
- **Usar `managedFieldsManagers` con client-side apply** — `managedFieldsManagers` requiere server-side apply activo para que `managedFields` tenga sentido.
- **Ignorar `/spec/replicas` en *todos* los Deployments del cluster** cuando solo uno tiene HPA — demasiado amplio. Usa `name:` para apuntar al Deployment específico.

## Limpieza

El ejemplo no aplica nada contra un cluster. Nada que limpiar.

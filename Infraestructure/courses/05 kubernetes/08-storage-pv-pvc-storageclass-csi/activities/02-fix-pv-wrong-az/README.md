# k8s-08-02 — Arreglar un PVC que termina en la AZ equivocada

## 1. Identificación

- **ID:** `k8s-08-02-fix-pv-wrong-az`
- **Tecnología:** kubernetes
- **Módulo:** `08-storage-pv-pvc-storageclass-csi`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** debug (independent)

## 2. Contexto

En un cluster EKS con nodos en `us-east-1a`, `us-east-1b` y `us-east-1c`, el equipo despliega un Deployment que exige correr en una zona concreta por motivos de latencia (`nodeSelector: topology.kubernetes.io/zone=us-east-1c`). El Deployment usa un PVC dinámico. Observan:

- El PVC se liga rápido a un PV.
- El Pod queda `Pending` con el mensaje `0/3 nodes are available: node(s) had volume node affinity conflict`.

El PV terminó en `us-east-1a`, pero el Pod solo puede ir a nodos de `us-east-1c`.

Esta actividad corre en **kind** (single-node, sin AZ real). *No puedes* reproducir el fallo observable, pero puedes:

- Leer y entender el manifest buggy.
- Aplicar la corrección en el manifest.
- Validar que la corrección es correcta.

## 3. Objetivos

- Diagnosticar por escrito la causa raíz.
- Modificar `starter/storageclass-bad.yaml` para que `volumeBindingMode` sea `WaitForFirstConsumer`.
- (Opcional) Añadir anotación o cambiar también `reclaimPolicy` a `Retain` con justificación.

## 4. Prerrequisitos

- `kubectl` para inspección (no obligatorio para el validador static).
- Haber leído la sección 5 de `theory/lesson.md`.

## 5. Instrucciones

> **No** mires `solution/` antes de intentarlo.

1. Lee los manifests del starter: `starter/storageclass-bad.yaml`, `starter/pvc.yaml`, `starter/deployment.yaml`.
2. Identifica qué dos campos (uno en la StorageClass, cero o más en el Pod/Deployment) interactúan mal.
3. Edita `starter/storageclass-bad.yaml` para corregirlo. **No** cambies el nombre del archivo.
4. Explica en un comentario `# fix: ...` dentro del YAML por qué el cambio arregla el fallo.
5. (Opcional) Si el cluster está disponible, aplica los manifests corregidos y observa que el PVC queda `Pending` hasta que el Pod aparece — contrario a lo que ocurría antes.
6. Corre el validador:

```bash
cd courses/kubernetes/08-storage-pv-pvc-storageclass-csi/activities/02-fix-pv-wrong-az
bash tests/validate.sh
```

## 6. Resultado esperado

- `starter/storageclass-bad.yaml` queda con `volumeBindingMode: WaitForFirstConsumer`.
- `starter/pvc.yaml` y `starter/deployment.yaml` no se modifican.
- Si tienes cluster disponible y aplicas los manifests, el PVC debe quedar `Pending` hasta que el Pod del Deployment lo solicite.

## 7. Criterios de aceptación

- `tests/validate.sh` exit code 0.
- El cambio hecho explica *por qué*, no solo *qué*.

## 8. Validación

```bash
bash tests/validate.sh
```

Verifica:

- `starter/storageclass-bad.yaml` existe.
- Contiene exactamente `volumeBindingMode: WaitForFirstConsumer`.
- **No** contiene `volumeBindingMode: Immediate`.
- `starter/pvc.yaml` y `starter/deployment.yaml` existen y están sintácticamente razonables (campos clave presentes).
- Si hay cluster disponible: opcionalmente aplica los manifests al namespace `k8s08-az` y verifica que el PVC se puede crear (en kind el comportamiento de scheduling es trivial, no se puede observar el conflicto AZ real).

## 9. Preguntas de reflexión

- ¿Por qué `Immediate` existe como opción? ¿En qué caso tendría sentido?
- Si en vez de `nodeSelector` el Deployment usara `topologySpreadConstraints` sobre `topology.kubernetes.io/zone`, ¿cambia el diagnóstico?
- ¿Cuánto tarda EBS en detachar y re-attachar cuando un Pod se reprograma a otro nodo *dentro* de la misma AZ?
- Si tu cluster EKS tiene `gp2` default con `Immediate`, ¿qué harías mañana?

## 10. Extensiones

1. Simula el fallo en kind con dos "zonas" artificiales: etiqueta el único nodo kind con `topology.kubernetes.io/zone=us-east-1a` y pide al Pod `us-east-1c`. Observa cómo queda `Pending` por `nodeAffinity` (aunque el motivo subyacente es distinto, el síntoma se parece).
2. Lee la doc oficial de EBS CSI sobre `topology.ebs.csi.aws.com/zone`.
3. Escribe un `ValidatingAdmissionPolicy` que rechace la creación de StorageClass con `volumeBindingMode: Immediate` fuera de un `allow-list` de nombres.

## 11. Limpieza

Si aplicaste algo a un cluster:

```bash
kubectl delete namespace k8s08-az --ignore-not-found
```

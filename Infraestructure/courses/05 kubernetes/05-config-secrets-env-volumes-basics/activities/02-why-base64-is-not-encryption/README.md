# k8s-05-02 — Por qué base64 no es cifrado (análisis)

## 1. Identificación

- **ID:** `k8s-05-02-why-base64-is-not-encryption`
- **Tecnología:** kubernetes
- **Módulo:** `05-config-secrets-env-volumes-basics`
- **Dificultad:** beginner
- **Duración estimada:** 50 min
- **Tipo:** independent (análisis)

## 2. Contexto

Esta actividad **no es de implementar**: es de **demostrar y argumentar**. Vas a probar con tus propias manos, en un cluster kind, que un `Secret` de Kubernetes vive en etcd como cleartext base64 — no cifrado — y vas a redactar un `ANALYSIS.md` que un auditor podría leer para entender por qué "tener Secrets" ≠ "tener secretos seguros".

El entregable principal es un **documento**: no basta con que tus comandos funcionen; tienes que *explicar* qué significa el output y qué recomendarías. El validador comprueba que `ANALYSIS.md` contenga las piezas canónicas (los comandos ejecutados, el output pegado literal, afirmaciones específicas, y la recomendación de ESO).

## 3. Objetivos

Al terminar deberías poder:

- Crear un Secret con un valor dummy y obtenerlo de vuelta en cleartext con un one-liner.
- Demostrar vía `kubectl exec` dentro del Pod que el valor también está disponible como env (si lo montas así).
- (Opcional avanzado) Mostrar que lo que etcd guarda es los mismos bytes base64 — vía snapshot o vía `kubectl get secret -o yaml`.
- Redactar un `ANALYSIS.md` que un auditor acepte como evidencia.

## 4. Prerrequisitos

- `kind`, `kubectl`, `base64`, `grep`.
- Un cluster kind (lo creamos si no existe).
- Sin costo.

## 5. Instrucciones

**No vamos a dictarte los comandos literal**. Esta es una actividad independiente: la lección te dio las piezas; organiza la demostración.

### Marco mínimo requerido

Tu `ANALYSIS.md` (ubicado en `/tmp/k8s-05-02/ANALYSIS.md`) debe contener, como mínimo:

1. **Sección "Setup"**: cómo creaste el cluster y el namespace. Pega los comandos.
2. **Sección "Creación del Secret"**: el `kubectl create secret generic ... --from-literal=password=<DUMMY>`. Usa un valor dummy único (sugerencia: `dummy-canary-XYZ789`) para poder *grep*earlo luego.
3. **Sección "Demostración 1 — base64 trivialmente revertible"**:
   - Pega el comando `kubectl get secret <nombre> -o jsonpath='{.data.password}' | base64 -d`.
   - Pega el output exacto.
   - Explica (dos frases) por qué esto prueba que `base64` es un encoding, no un cifrado.
4. **Sección "Demostración 2 — grep del cleartext"**:
   - Ejecuta `kubectl get secret <nombre> -o yaml` y busca con `grep` el string base64 que corresponde a tu DUMMY. Documenta ambos: el base64 (como aparece) y el `echo <base64> | base64 -d` que lo revierte.
   - **(Opcional, +puntos)**: en un cluster kind, el nodo es un contenedor; puedes `docker exec` al nodo y usar `etcdctl` para leer la clave `/registry/secrets/<ns>/<nombre>` y verificar que el valor base64 vive así tal cual en etcd. Si lo haces, pégalo. Si no, al menos cita cómo lo harías.
5. **Sección "Afirmaciones específicas"** (el validador busca estos literales):
   - La frase `"base64 es un encoding, no un cifrado"` (o variación con esas palabras clave: `encoding`, `cifrado`).
   - La frase que incluya `"EncryptionConfiguration"` explicando qué habilita en el apiserver.
   - La frase que incluya `"etcd"` y aclare que sin `EncryptionConfiguration` los Secrets viven como base64 cleartext.
6. **Sección "Recomendación"**: por qué un Secret manager externo (**External Secrets Operator** nombrado explícitamente) mitiga este riesgo mejor que confiar solo en RBAC `get secrets`. Mínimo 3 argumentos.

### Pistas (no spoilers)

- `kubectl explain secret.data` te dice qué es realmente el campo.
- `base64 -d` existe en macOS (BSD base64) y en Linux (coreutils) con bandera distinta; en BSD a veces es `base64 -D`. Usa lo que te sirva.
- Para la demostración opcional de etcd en kind: `docker exec -it <kind-control-plane-container> sh`; luego `etcdctl` está en `/usr/local/bin/etcdctl` dentro del nodo kind. Las certs las encuentras en `/etc/kubernetes/pki/etcd/`. Ejemplo:
  ```
  ETCDCTL_API=3 etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/peer.crt \
    --key=/etc/kubernetes/pki/etcd/peer.key \
    get /registry/secrets/<ns>/<name>
  ```
  (El valor sale "feo" porque está serializado como protobuf, pero los bytes base64 de la password se ven en claro.)

### Lo que NO debes hacer

- No subas secretos reales ni los pegues en el `ANALYSIS.md`. El validador asume `dummy-canary-XYZ789` o similar.
- No cites "lo oí en un podcast". Si afirmas algo, respáldalo con un comando y su output.

## 6. Resultado esperado

- `/tmp/k8s-05-02/ANALYSIS.md` existe y contiene las 6 secciones.
- El validador detecta: la cadena base64 esperada, su decodificación cleartext, las afirmaciones clave y la mención a ESO.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- Un revisor humano leyendo tu `ANALYSIS.md` entiende en 2 min por qué los Secrets no están cifrados y qué recomendarías. (El validador aproxima esto por heurísticas de contenido.)

## 8. Validación

```bash
bash courses/kubernetes/05-config-secrets-env-volumes-basics/activities/02-why-base64-is-not-encryption/tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si tienes `EncryptionConfiguration` en el apiserver pero *no* rotas las llaves cada N meses, ¿qué riesgos subsisten?
2. ¿`kubectl get secret -o yaml` lee de etcd directamente? Si no, ¿qué lo intermedia?
3. ¿Un backup de etcd (`etcdctl snapshot save`) incluye los Secrets? ¿Cómo cambia la respuesta con `EncryptionConfiguration` activo?
4. ¿Qué `Role`/`ClusterRole` concede exactamente `get secrets`? ¿Cómo auditas quién lo tiene?

## 10. Extensiones

- Repite todo con `EncryptionConfiguration` **activo** y compara qué cambia en el output de `etcdctl get`.
- Instala ESO en el cluster kind y conecta a un backend fake (ej.: `kubernetes` provider usando otro Secret como fuente). Documenta cómo cambia el ciclo de vida.

## 11. Limpieza

```bash
kubectl delete namespace demo-canary --wait=false 2>/dev/null || true
rm -rf /tmp/k8s-05-02
# kind delete cluster --name k8s-05   # opcional
```

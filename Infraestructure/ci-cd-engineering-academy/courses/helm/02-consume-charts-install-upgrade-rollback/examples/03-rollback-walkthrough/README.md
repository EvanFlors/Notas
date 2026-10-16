# Ejemplo 03 — `helm rollback` paso a paso

## Concepto que demuestra

Qué hace realmente `helm rollback`: lee el Secret de la revisión target, lo deserializa, y **crea una revisión nueva** (N+1) que es una copia de la revisión K elegida. La historia no se "deshace"; crece.

## Contexto

Instalamos ingress-nginx, hacemos un upgrade con un valor claramente "cuestionable" (replicaCount=3), confirmamos la revisión 2, y hacemos rollback a la revisión 1. Verificamos que:

- La historia queda con 3 filas (1 superseded, 2 superseded, 3 deployed).
- La revisión 3 tiene los *mismos valores* que la revisión 1.
- Aparece un tercer Secret `sh.helm.release.v1.<release>.v3`.

Trabajamos en `/tmp/helm-02-ex03/`.

## Objetivo

Al terminar sabrás:

- Leer `helm history` como un log de operaciones.
- Hacer rollback a una revisión concreta.
- Entender por qué el rollback aparece como una revisión nueva y no como un "`git reset`".

## Prerrequisitos

- Cluster local funcional.
- `helm` ≥ 3.14, `kubectl` ≥ 1.28.

## Ejecución

```bash
# 0. Entorno limpio.
mkdir -p /tmp/helm-02-ex03 && cd /tmp/helm-02-ex03

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update ingress-nginx >/dev/null

# 1. Revisión 1: install de "producción feliz".
helm upgrade --install demo ingress-nginx/ingress-nginx \
  --namespace demo-rollback --create-namespace \
  --version 4.11.3 \
  --set controller.service.type=ClusterIP \
  --set controller.replicaCount=1 \
  --wait --timeout 5m

helm history demo -n demo-rollback
#   revision 1 | deployed

# 2. Revisión 2: upgrade "sospechoso" (más réplicas que tu cluster puede sostener
#    cómodamente). Para efectos de este walkthrough solo cambia replicaCount.
helm upgrade --install demo ingress-nginx/ingress-nginx \
  --namespace demo-rollback \
  --version 4.11.3 \
  --set controller.service.type=ClusterIP \
  --set controller.replicaCount=3 \
  --wait --timeout 5m

helm history demo -n demo-rollback
#   revision 1 | superseded
#   revision 2 | deployed
kubectl get deploy -n demo-rollback -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas

# 3. Mirar los Secrets ANTES del rollback.
kubectl get secret -n demo-rollback -l owner=helm
#   sh.helm.release.v1.demo.v1  (superseded)
#   sh.helm.release.v1.demo.v2  (deployed)

# 4. ROLLBACK a la revisión 1.
helm rollback demo 1 -n demo-rollback --wait --timeout 5m
#   NOTA: NO le decimos "borra la 2". Decimos "aplica el contenido de la 1
#   como si fuera un nuevo upgrade". Resultado: aparece una revisión 3.

helm history demo -n demo-rollback
#   revision 1 | superseded
#   revision 2 | superseded
#   revision 3 | deployed      <-- DESCRIPTION dice "Rollback to 1"

# 5. Mirar los Secrets DESPUÉS del rollback.
kubectl get secret -n demo-rollback -l owner=helm
#   sh.helm.release.v1.demo.v1  (superseded)
#   sh.helm.release.v1.demo.v2  (superseded)
#   sh.helm.release.v1.demo.v3  (deployed)   <-- NUEVO

# 6. Verificar que, efectivamente, la revisión 3 tiene los valores de la 1.
echo "---- values revision 1 ----"
helm get values demo -n demo-rollback --revision 1
echo "---- values revision 3 (post-rollback) ----"
helm get values demo -n demo-rollback --revision 3
#   Deben ser IDÉNTICOS: replicaCount=1 y service.type=ClusterIP.

# 7. Verificar que el cluster volvió a 1 réplica.
kubectl get deploy -n demo-rollback -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas
```

## Resultado esperado

- `helm history demo -n demo-rollback` muestra 3 filas, con la 3 en `deployed` y descripción `Rollback to 1`.
- Hay 3 Secrets `sh.helm.release.v1.demo.v{1,2,3}` en el namespace.
- `helm get values --revision 1` y `--revision 3` imprimen los mismos valores.
- `kubectl get deploy` muestra `DESIRED=1` (volvió al estado de la revisión 1).

## Limpieza

```bash
helm uninstall demo -n demo-rollback
kubectl delete namespace demo-rollback --ignore-not-found
rm -rf /tmp/helm-02-ex03
```

## Preguntas de reflexión

1. Si después del rollback haces `helm rollback demo 2 -n demo-rollback`, ¿qué revisión aparece y con qué contenido?
2. ¿Por qué `helm rollback` puede fallar? Da un ejemplo concreto (pista: campos inmutables, p. ej. `Service.spec.clusterIP`).
3. ¿Qué devuelve `helm status demo -n demo-rollback --revision 2` en este punto? ¿Y qué pasa si borras *solo* el Secret `sh.helm.release.v1.demo.v2`?
4. Si quisieras conservar la historia tras un `helm uninstall` (para auditar qué revisiones hubo), ¿qué flag usarías?

# Solución — obs-12-01

Esta actividad es guiada: la **solución es exactamente** `starter/bootstrap.sh`. El estudiante no tiene que inventar, tiene que entender.

Lectura recomendada tras ejecutar:

- `theory/lesson.md` §2 (arquitectura del Operator) para asociar cada pod con un rol.
- `theory/lesson.md` §6 (selectors) para explicar por qué quitar `release: kps` del ServiceMonitor rompe el scrape.
- `theory/lesson.md` §8 para explicar por qué quitar la label `grafana_dashboard=1` deja el dashboard invisible.

## Respuestas a las preguntas de reflexión

1. **Por qué `release: kps` es necesaria**: el `Prometheus` CR instalado por KPS trae `serviceMonitorSelector.matchLabels.release=kps`. Sin esa label el Operator ignora el CR sin error.
2. **Confirmar que lo ignoró**: inspeccionar el `prometheus.yml` generado y comprobar que **no** aparece el `job_name` de la app:
   ```bash
   kubectl -n monitoring get secret prometheus-kps-kube-prometheus-stack-prometheus \
     -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | grep fastapi
   ```
3. **Dashboard sin label**: el sidecar `k8s-sidecar` no lo copia a Grafana; el ConfigMap existe pero el dashboard no aparece. Si está en namespace equivocado y el sidecar está configurado con `searchNamespace=ALL` (default en KPS), igual lo recoge; si está limitado a `monitoring`, no.
4. **Componentes desactivados en kind**: kind no expone etcd / controller-manager / scheduler / kube-proxy con endpoints metrics scrapeable desde cluster. Dejar los jobs activos genera targets en rojo (ruido) sin añadir valor en laboratorio.
5. **`prometheus.yml` generado**: vive como `Secret` (no ConfigMap) porque podría contener credenciales (bearer tokens, basic auth); es más adecuado que un ConfigMap plano.

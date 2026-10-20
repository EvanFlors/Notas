# Actividad 01 — Chart Helm propio para la app FastAPI

## 1. Identificacion

- **ID:** `cap-09-01-build-helm-chart`
- **Tecnologia:** capstone
- **Modulo:** `09-helm-chart-argocd`
- **Dificultad:** intermediate
- **Duracion estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a cerrar la primera mitad de la etapa 9 produciendo un chart Helm propio
para la app FastAPI del capstone, bajo `charts/fastapi-app/`. El chart ya esta
en el repo como referencia; aqui lo construyes mentalmente y corres los
validadores (`helm lint`, `helm template`, prueba de rechazo del schema) para
demostrar que entendiste cada decision.

## 3. Objetivos

- Entender la anatomia de un chart (`Chart.yaml`, `values.yaml`, `templates/`,
  `_helpers.tpl`, `NOTES.txt`, `tests/`).
- Correr `helm lint` + `helm template` + un check contra `values.schema.json`.
- Verificar que un valor invalido es rechazado por el schema.
- Justificar las decisiones del chart (checksum, securityContext, probes).

## 4. Prerrequisitos

- `helm` v3.14+ (`helm version`). Si no esta, el validador reporta `SKIP`.
- `bash`/`zsh` y permisos de escritura en `/tmp/`.
- Opcional: `kubeconform` para validacion extra.

## 5. Instrucciones

### Paso 1 — Inspecciona el chart

```bash
cd projects/capstone/stages/09-helm-chart-argocd
ls charts/fastapi-app/
cat charts/fastapi-app/Chart.yaml
```

Identifica: `type`, `version` (chart) vs `appVersion` (imagen), `kubeVersion`.

### Paso 2 — Lint

```bash
helm lint charts/fastapi-app
```

Debe terminar con `1 chart(s) linted, 0 chart(s) failed`.

### Paso 3 — Template

```bash
helm template fastapi charts/fastapi-app \
  --values charts/fastapi-app/values-dev.yaml \
  --namespace fastapi-dev \
  --output-dir /tmp/cap-09-01
ls /tmp/cap-09-01/fastapi-app/templates/
```

Deberias ver: `deployment.yaml`, `service.yaml`, `configmap.yaml`,
`secret.yaml`, `serviceaccount.yaml`. `ingress.yaml` y `hpa.yaml` NO aparecen
porque sus toggles estan en `false` por defecto.

### Paso 4 — Prueba el schema

Crea un override invalido y confirma que `helm template` lo rechaza:

```bash
cat > /tmp/cap-09-01-bad.yaml <<'YAML'
replicaCount: "dos"
YAML
helm template fastapi charts/fastapi-app \
  --values charts/fastapi-app/values.yaml \
  --values /tmp/cap-09-01-bad.yaml && echo "ERROR: deberia haber fallado" || echo "OK: schema rechazo el valor"
```

### Paso 5 — NOTES.txt

```bash
helm template fastapi charts/fastapi-app --values charts/fastapi-app/values-dev.yaml \
  --show-only templates/NOTES.txt 2>/dev/null || true
# NOTES.txt no se renderiza con `template --show-only`; usa dry-run:
helm install --dry-run --debug fastapi charts/fastapi-app \
  --values charts/fastapi-app/values-dev.yaml 2>/dev/null | sed -n '/NOTES:/,$p' | head -30
```

### Paso 6 — Validador

```bash
bash activities/01-build-helm-chart/tests/validate.sh
```

Debe terminar en `RESULT: 0 issue(s).`.

## 6. Entregables

- Output de `helm lint` guardado como evidencia.
- Carpeta `/tmp/cap-09-01/` con los manifests renderizados.
- Confirmacion de que el schema rechazo `replicaCount: "dos"`.
- Validador en verde.

## 7. Pistas

1. Si `helm template` falla con "parse error", corre con `--debug` para ver
   el YAML a medio renderizar y el stack trace.
2. Si el schema NO rechaza el valor invalido, revisa que
   `charts/fastapi-app/values.schema.json` siga teniendo
   `"replicaCount": { "type": "integer", ... }`.
3. Si `helm lint` se queja de `icon`, es un warning, no un fail (puedes
   ignorarlo o anadir `icon:` al Chart.yaml).

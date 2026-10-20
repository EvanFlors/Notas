# Ejemplo 03 — Operación air-gapped con `helm pull`

## Concepto que demuestra

Simular una organización air-gapped: el chart se produce en un "entorno con red" y se consume en un "entorno sin red" sólo con el `.tgz` descargado. Validación: `helm template` y `helm install --dry-run` sin volver al registry.

Soporta:

- **`MODE=local`** (default) — "entorno con red" = `registry:2` en `localhost:5000`. "Entorno air-gapped" simulado desactivando el acceso al registry (apagamos el contenedor antes de instalar). Operaciones de install vía `--dry-run` (no requiere cluster real).
- **`MODE=live`** — pull real desde `oci://ghcr.io/<org>/charts/<name>` a un directorio local; luego instala desde el `.tgz` sin más llamadas al registry. Si tienes `kubectl` + un cluster, puede hacer un install real con `KUBE=1`.

## Contexto

Ver `theory/lesson.md` §10 (air-gap) y §11 (errores comunes: `helm dependency update` antes de empaquetar).

## Archivos

- `run.sh` — pipeline producer → transporte → consumer.

## Ejecución

### MODE=local

```bash
bash run.sh
```

Fases:

1. **Producer**: `registry:2` en 5000, chart `airgap-demo` con *una* subchart dependency inline → `helm dependency update` → `helm package` → `helm push`.
2. **Transporte**: `helm pull oci://localhost:5000/...` al directorio `transport/`.
3. **Air-gap**: `docker stop` del registry (ahora *no* hay red hacia él). `helm template` + `helm install --dry-run` **desde el `.tgz`** → render exitoso.
4. **Prueba negativa**: `helm pull oci://localhost:5000/...` **falla** (registry caído), confirmando que no se está contactando.

### MODE=live

```bash
MODE=live REGISTRY=ghcr.io/yourorg CHART=charts/signed-demo VERSION=0.1.0 bash run.sh
# opcional, con cluster real:
MODE=live KUBE=1 ... bash run.sh
```

## Qué mirar

- El `.tgz` descargado contiene `charts/` con **todas** las dependencias ya resueltas. Verifícalo con:

  ```bash
  tar -tzf transport/airgap-demo-0.1.0.tgz | head -20
  ```

- `helm template` del `.tgz` funciona sin red: la "network" no se usa para render.

## Limpieza

```bash
docker rm -f helm-08-ex03-reg 2>/dev/null || true
rm -rf /tmp/helm-08-ex03
```

## Referencias

- `theory/lesson.md` §10.
- `resources/links.md` → Helm registries, oras, crane (para mirror avanzado).

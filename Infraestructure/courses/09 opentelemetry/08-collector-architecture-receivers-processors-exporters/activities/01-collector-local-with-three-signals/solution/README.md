# Solucion — Actividad 01

La config final es practicamente la misma del `starter/`. El objetivo era levantarla, enviar las 3 signals y verificar los archivos.

## Pasos clave que debes dominar

1. **Validar primero**:
   ```sh
   docker run --rm -v "$PWD/config.yaml:/c.yaml:ro" \
     otel/opentelemetry-collector-contrib:latest validate --config=/c.yaml
   ```
2. **Correr en background** (igual que lo hace `tests/validate.sh`) y esperar la linea `"Everything is ready"` en los logs.
3. **Mandar signals con `telemetrygen`** (una invocacion por signal).
4. **Esperar al menos `batch.timeout` segundos** antes de verificar los archivos (sino el `file` exporter aun no vacio su buffer).
5. **Limpiar** siempre: `docker rm -f otel-lab-collector; rm -rf /tmp/otel-lab`.

## Troubleshooting comun

- **"connection refused"** desde telemetrygen -> el collector no esta listo todavia (esperar) o el puerto no esta mapeado.
- **Archivos vacios** -> el batch no ha hecho flush; aumentar la espera o bajar `batch.timeout`.
- **"unknown type: file"** -> estas usando la distro `core` y no `contrib`.
- **Container no puede escribir a `/out`** -> `chmod 777 /tmp/otel-lab` antes de montar.

# Starter — obs-05-01

Dos archivos están incompletos:

- `docker-compose.yml`: le falta el servicio `postgres-exporter`.
- `prometheus.yml`: le falta el `job_name: postgres` con relabel.

Edita ambos siguiendo el README de la actividad. No modifiques el servicio `postgres` (ya está configurado con DB `demo` y user `demo_user`).

Cuando termines:

```bash
docker compose up -d
sleep 20
curl -s 'http://localhost:9090/api/v1/query?query=pg_up'
```

Y desde el directorio padre:

```bash
bash tests/validate.sh
```

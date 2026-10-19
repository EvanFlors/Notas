# Ejemplo 01 — Habilitar todos los templates de seguridad

> Lectura y análisis. Objetivo: ver el **mínimo YAML viable** para habilitar 5+ scanners nativos y entender qué variables de ajuste existen.

## 1. El `.gitlab-ci.yml`

Ver `.gitlab-ci.yml` en este directorio. Lo relevante:

- `stages:` incluye `test` (obligatorio: los jobs de los templates van ahí por defecto).
- Cinco `include:template:` apuntando a `Jobs/*.gitlab-ci.yml` oficiales.
- `variables:` globales para ajustar paths excluidos y nivel de log.
- `workflow:` top-level para evitar pipelines duplicados en MR + branch.

## 2. Lectura clave

1. **No se copia el YAML del scanner**. Cada `include:template:` se resuelve en el server contra la versión del GitLab server. Si GitLab publica un fix a SAST, lo recibes al próximo pipeline.
2. **El job no se declara explícitamente**. El template lo trae. Si quieres `extends:` o cambiar `image:`, lo haces redefiniendo el job por nombre (`sast:`, `secret_detection:`, …) debajo del `include:`.
3. **Los reports van automáticos**. Cada template declara `artifacts: reports: sast: gl-sast-report.json` (o el que corresponda) y GitLab los consume para el Dashboard y el widget de MR.
4. **DAST no está** en este ejemplo porque requiere Ultimate y una URL desplegada. Se añade en pipelines con un stage `deploy-review` previo.
5. **Container Scanning** requiere que exista una imagen en el registry; el template arranca después del job `build` si está en un stage anterior.

## 3. Verificación local

```bash
# Validacion sintactica YAML.
python3 -c 'import yaml,sys; yaml.safe_load(open(".gitlab-ci.yml"))'

# Contar includes.
grep -c 'template:' .gitlab-ci.yml
```

## 4. Qué omitimos a propósito

- `tags:` para seleccionar runner — en SaaS cualquier shared runner sirve.
- `rules:` fino por branch — está en `workflow:` global.
- Pin de versión del template (`ref:` en `include:project:`). En Self-Managed con `include:remote:` se usa; en `include:template:` siempre se usa la versión del server.

# Actividad 01 — Least privilege con role predefinido + deny policy

> Independiente. Sin GCP real. YAML validado estructuralmente con `python3` + `bash`.

## 1. Escenario

Trabajas en Acme. Hay un Cloud Run service en `acme-prod` llamado `receipts-processor` que:

- **Lee** objetos del bucket `gs://acme-prod-receipts-raw` (los recibos crudos).
- **Escribe** objetos en el bucket `gs://acme-prod-receipts-processed` (los procesados).
- **Publica** mensajes a un Pub/Sub topic `projects/acme-prod/topics/receipts-events`.

El workload corre con la service account `receipts-processor@acme-prod.iam.gserviceaccount.com` (ya creada).

Un ex-arquitecto le dio `roles/editor` en todo el project "para que funcione sin pensar". Tu trabajo es **sustituirlo** por bindings de **mínimo privilegio** con **roles predefinidos**, y añadir una **deny policy** complementaria que evite que *cualquiera* (incluidos admins) borre los dos buckets de recibos, excepto el grupo break-glass `break-glass-storage@acme.io`.

> **Importante**: la actividad es **papel** — no se despliega nada. Pero los YAML que entregas deben ser los que **realmente** aplicarías con `gcloud` / Terraform.

## 2. Qué debes entregar

En `/tmp/gcp-02-lpp/`:

1. **`iam-bindings.yaml`** — una lista YAML con bindings mínimos para la SA del workload. Debe:
   - Usar **solo** roles predefinidos (`roles/<service>.<role>`). **No** basic (`roles/owner|editor|viewer`).
   - Mencionar como `member` a `serviceAccount:receipts-processor@acme-prod.iam.gserviceaccount.com`.
   - Cubrir los tres accesos (lectura raw, escritura processed, publish Pub/Sub).
   - YAML válido (parsea con `python3 -c "import yaml; yaml.safe_load(open('...'))"`).

2. **`deny-policy.yaml`** — una deny policy para proteger el borrado de los dos buckets. Debe:
   - Tener `name`, `displayName`, `rules`.
   - Al menos una regla con `denyRule`.
   - `deniedPrincipals: [principalSet://goog/public:all]`.
   - `exceptionPrincipals` incluyendo `principalSet://goog/group/break-glass-storage@acme.io`.
   - `deniedPermissions` que incluya **al menos** `storage.googleapis.com/buckets.delete` (nombre **cualificado** con `.googleapis.com/`).
   - YAML válido.

3. **`README-INTENT.md`** — documento Markdown que justifica. Debe incluir, al menos:
   - Sección `# iam-bindings` (o similar reconocible) donde justificas **cada** role elegido y **por qué no `roles/editor`**.
   - Sección `# deny-policy` donde explicas qué veta, a quién, y la razón del break-glass.
   - Mención explícita de **"predefined"** y de **"break-glass"**.
   - Mención de **al menos un role predefinido** por nombre canónico (p. ej. `roles/storage.objectViewer`).

## 3. Pistas de diseño

- `objectViewer` lee, `objectCreator` escribe (sin sobrescribir), `objectUser` lee + escribe + borra objetos propios. Para "lee del raw" vs "escribe en processed", **dos bindings** distintos en dos recursos distintos (dos buckets).
- Para Pub/Sub publisher, `roles/pubsub.publisher`.
- Deny policies **no** aceptan nombres cortos de permisos; usa `storage.googleapis.com/buckets.delete`, no `storage.buckets.delete`.
- Puedes añadir una segunda regla a la deny policy para `buckets.setIamPolicy` si quieres cerrar el otro vector de abuso (opcional, no requerido por el validador).

## 4. Cómo validar

```
mkdir -p /tmp/gcp-02-lpp
cp mis-archivos/*.yaml mis-archivos/README-INTENT.md /tmp/gcp-02-lpp/
bash tests/validate.sh /tmp/gcp-02-lpp
```

El validador verifica estructura, no semántica profunda. Compara con `solution/REFERENCE.md` para autoevaluarte conceptualmente.

## 5. Ejemplo mental de un binding mal diseñado

```yaml
# MAL — demasiado amplio
- role: roles/storage.admin
  members:
    - serviceAccount:receipts-processor@acme-prod.iam.gserviceaccount.com
```

`storage.admin` incluye `buckets.delete`, `buckets.setIamPolicy` y mucho más. Para un workload que solo lee de un bucket y escribe en otro, es exceso descomunal.

## 6. Criterios de autoevaluación semántica

- ¿Tu binding le daría al workload más permisos de los que la descripción pide?
- Si borras el binding de publish, ¿el workload falla **solo** la operación de publicar? (Debería.)
- Si un atacante compromete la SA, ¿puede borrar los buckets? (Con tu deny policy correcta: **no**.)
- ¿Hay algún `user:` en tus bindings? (No debería haber ninguno.)

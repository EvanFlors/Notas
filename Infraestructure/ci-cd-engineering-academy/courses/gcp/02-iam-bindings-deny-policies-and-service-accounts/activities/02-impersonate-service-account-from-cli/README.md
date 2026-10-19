# Actividad 02 — Impersonar una SA desde `gcloud` (walkthrough)

> Independiente. Sin GCP real. YAML + Markdown validados estructuralmente.
>
> **Walkthrough only**: ningún comando se ejecuta contra GCP. El objetivo es dejar documentado el patrón correcto para cuando sí se opere en una org real.

## 1. Escenario

El equipo de platform (`group:platform-eng@acme.io`) necesita desplegar nuevas revisiones del servicio Cloud Run `receipts-processor` en `acme-prod`. **Los humanos no tienen bindings directos de deployment en `acme-prod`** — por diseño: ningún humano debe tener permisos directos para modificar prod.

Existe una service account de deployment `deployer@acme-prod.iam.gserviceaccount.com` que **sí** tiene los roles necesarios en `acme-prod` (`roles/run.admin` + `roles/iam.serviceAccountUser` sobre la runtime SA, limitado por un deny policy para no borrar servicios).

Tu trabajo:

1. Diseñar el binding **sobre la SA de deployment** que permite al grupo platform **impersonar** a `deployer@...`.
2. Documentar los comandos `gcloud` que un humano del grupo usaría — paso a paso — para desplegar via impersonation.
3. Documentar **por qué no se emite una SA key** para `deployer@...` (anti-patrón), con referencia a la org policy que lo refuerza.

## 2. Qué debes entregar

En `/tmp/gcp-02-impersonate/`:

1. **`token-creator-binding.yaml`** — allow policy YAML aplicado **sobre la SA destino `deployer@acme-prod.iam.gserviceaccount.com`**. Debe:
   - Contener un binding con `role: roles/iam.serviceAccountTokenCreator`.
   - Contener `members` incluyendo `group:platform-eng@acme.io`.
   - YAML válido (parsea con `python3 -c "import yaml; ..."`).

2. **`IMPERSONATION-WALKTHROUGH.md`** — documento Markdown con **al menos** las siguientes secciones (headings reconocibles):
   - `# Flujo de impersonation` (o similar que contenga "flujo"/"impersonation") — pasos 1–N con los comandos `gcloud` concretos. Debe mencionar:
     - `gcloud auth login`
     - `--impersonate-service-account=deployer@acme-prod.iam.gserviceaccount.com` (o equivalente)
     - `roles/iam.serviceAccountTokenCreator`
     - `iamcredentials.googleapis.com` (la API que emite el token efímero)
   - `# Por qué NO SA key` (o similar que contenga "no" y "key" o "SA key" / "anti-patron") — explicación con al menos **3 razones** (expiración, rotación, auditabilidad, incident response). Mención explícita de:
     - `iam.disableServiceAccountKeyCreation` (la constraint que lo refuerza)
     - `Workload Identity Federation` (WIF) como alternativa correcta para cargas externas
   - `# Auditoria` (o "audit" / "logs") — explicación de cómo humano **y** SA destino aparecen en los audit logs. Mención explícita de:
     - `serviceAccountDelegationInfo` (campo que registra la cadena de impersonation)
     - `principalEmail`

## 3. Pistas de diseño

- El binding `roles/iam.serviceAccountTokenCreator` va **sobre la SA**, no sobre el project. En Terraform es `google_service_account_iam_binding`, no `google_project_iam_binding`.
- `gcloud --impersonate-service-account=<SA>` funciona con cualquier comando `gcloud`. Alternativa: `gcloud config set auth/impersonate_service_account <SA>` (persistente para la configuración activa).
- La API que materializa el token efímero es `iamcredentials.googleapis.com` (debe estar habilitada en el project que **hospeda** la SA destino, no en el del humano).
- Audit logs: en `acme-prod`, cada acción del deployer deja un registro con `authenticationInfo.principalEmail = deployer@...` y `authenticationInfo.serviceAccountDelegationInfo[0].firstPartyPrincipal.principalEmail = alice@acme.io`. Esta cadena es la **evidencia** de quién hizo qué.

## 4. Cómo validar

```
mkdir -p /tmp/gcp-02-impersonate
cp mis-archivos/token-creator-binding.yaml mis-archivos/IMPERSONATION-WALKTHROUGH.md /tmp/gcp-02-impersonate/
bash tests/validate.sh /tmp/gcp-02-impersonate
```

El validador verifica estructura. Compara con `solution/` para evaluación semántica.

## 5. Mandatorio para aprobar

- **Walkthrough only** — no incluyas instrucciones que ejecuten contra GCP. Esto es intencional: la actividad es análisis + patrón.
- **No** incluyas comandos de creación o descarga de SA keys. La única mención a SA keys es como **anti-patrón** que **no** se usa.
- **No** uses `user:` directo en el binding — usa el grupo.

## 6. Criterios de autoevaluación semántica

- Si Alice (del grupo) ejecuta un deploy, ¿los audit logs permiten saber que fue ella y no otra persona?
- Si Alice sale de la empresa y HR la saca del grupo, ¿en cuántos segundos pierde la capacidad de desplegar?
- Si alguien pidiera "dame una key del deployer para automatizar", ¿cuáles son las dos alternativas correctas que le ofreces (una para GCP interno, una para fuera de GCP)?
- ¿Qué pasa si `iamcredentials.googleapis.com` no está habilitada en `acme-prod`?

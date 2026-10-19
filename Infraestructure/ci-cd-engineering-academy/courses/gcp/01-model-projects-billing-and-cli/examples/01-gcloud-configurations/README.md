# Ejemplo 01 — `gcloud` configurations

> Lectura y analisis. **Sin ejecucion contra GCP real**. Si `gcloud` esta instalado en tu laptop, puedes correr los comandos `list`/`get-value` sin riesgo; cualquier `set` crea entradas locales en `~/.config/gcloud/` sin impactar GCP. Usamos el placeholder `my-project-123` que **no existe**.

## 1. El problema que resuelven

Trabajas en 2 projects (`checkout-dev` y `checkout-prod`), con 2 identidades distintas (una personal, una de breakglass), y 2 regiones diferentes. Sin configurations, acabas con un `.bashrc` lleno de `export CLOUDSDK_CORE_PROJECT=...` que se te olvida cambiar y haces `gcloud compute instances delete` en el proyecto equivocado.

**Configurations** son perfiles con nombre que agrupan `account`, `project`, `region`, `zone` y otras properties. Alternas con un comando; `gcloud` muestra en el prompt la activa.

## 2. Anatomia

```
~/.config/gcloud/
├── active_config                          <- texto plano con el nombre del config activo
├── configurations/
│   ├── config_default
│   ├── config_dev
│   └── config_prod
├── credentials.db                         <- tokens de `gcloud auth login`
└── application_default_credentials.json   <- credenciales ADC (otro sistema; ver ejemplo 02)
```

Cada archivo `config_*` es un INI simple:

```ini
[core]
project = my-project-123
account = alice@acme.io

[compute]
region = europe-west1
zone = europe-west1-b

[auth]
impersonate_service_account = deployer@my-project-123.iam.gserviceaccount.com
```

## 3. Ciclo de vida

```bash
# Listar configuraciones existentes
gcloud config configurations list

# Crear
gcloud config configurations create dev
# Activarla (lo hace automatico al crearla)
gcloud config configurations activate dev

# Rellenar properties
gcloud config set project my-project-123
gcloud config set account alice@acme.io
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-b

# Verificar
gcloud config list
# Output esperado:
# [compute]
# region = europe-west1
# zone = europe-west1-b
# [core]
# account = alice@acme.io
# project = my-project-123
# Your active configuration is: [dev]

# Crear un segundo config para prod (ReadOnly)
gcloud config configurations create prod
gcloud config set project my-project-456
gcloud config set account alice@acme.io
gcloud config set compute/region europe-west1

# Alternar
gcloud config configurations activate dev     # vuelve al de dev
gcloud config configurations activate prod    # salta a prod
```

## 4. Patrones utiles

### 4.1 Impersonation permanente en un config

En lugar de pasar `--impersonate-service-account=...` en cada comando:

```bash
gcloud config set auth/impersonate_service_account deployer@my-project-123.iam.gserviceaccount.com
```

A partir de ese momento, **todas** las llamadas desde ese config impersonan a `deployer`. Para desactivar: `gcloud config unset auth/impersonate_service_account`.

### 4.2 Property por invocacion (sin pisar el config)

```bash
# Comando puntual con un project distinto, sin cambiar el config activo
gcloud compute instances list --project=other-project-789
```

Siempre preferible a `gcloud config set project other...` + comando + volver.

### 4.3 Variables de entorno vs properties

Las properties se **sobreescriben** por variables de entorno `CLOUDSDK_*`:

```bash
CLOUDSDK_CORE_PROJECT=my-project-123 gcloud compute instances list
```

Util para scripts CI/CD, donde no quieres estado persistente.

## 5. Property importantes a conocer

| Property | Que controla |
|----------|--------------|
| `core/project` | project por default. |
| `core/account` | identidad por default. |
| `core/disable_prompts` | `true` para no-interactivo (CI). |
| `compute/region` | region default para `gcloud compute *`. |
| `compute/zone` | zona default. |
| `run/region` | region default para `gcloud run *`. |
| `artifacts/location` | region default para `gcloud artifacts *`. |
| `auth/impersonate_service_account` | **todas** las llamadas se impersonan. |
| `billing/quota_project` | project que se cobra por quotas de API en algunas llamadas (relevante para ADC). |

## 6. Trampas habituales

1. **`gcloud init` crea un config nuevo o reconfigura `default`**. Si corres `gcloud init` sin pensar, puedes pisar tu `default`. Mejor: `gcloud config configurations create <nombre>` + rellenar manualmente.
2. **`default` siempre existe**. No se puede borrar. Si lo dejas sin properties utiles y activas otro, da igual. Si trabajas regularmente, no uses `default`: crea `dev`, `prod`, `sandbox`.
3. **Las properties NO viajan con `gcloud auth login`**. Login y config son dos sistemas distintos. Puedes tener credenciales de 3 usuarios y 5 configs, en cualquier combinacion.
4. **El prompt de la shell no cambia solo**. Si quieres ver el config activo en el prompt, hay snippets `PS1` que llaman a `gcloud config configurations list --filter=is_active:true --format="value(name)"` (cuidado con el coste de llamarlo en cada prompt).

## 7. Como se ve en la practica (sin GCP real)

```bash
# Esta sesion no toca GCP; solo escribe en ~/.config/gcloud/
gcloud config configurations create demo
gcloud config set project my-project-123
gcloud config set account alice@acme.io
gcloud config set compute/region europe-west1
gcloud config list
# ...
gcloud config configurations delete demo
# "Deleted [demo]."
```

El archivo `~/.config/gcloud/configurations/config_demo` existe mientras no lo borres. **No** has llamado a ninguna API ni creado nada en GCP.

## 8. Preguntas de autocomprobacion

1. Si tienes `core/account = alice@acme.io` en el config `dev` y `core/account = bob@acme.io` en `prod`, ¿que cuenta se usa cuando ejecutas `gcloud compute instances list` con `prod` activo?
2. ¿Cual es la diferencia entre `gcloud config set compute/region europe-west1` y `export CLOUDSDK_COMPUTE_REGION=europe-west1`? ¿Cual gana?
3. Si pones `auth/impersonate_service_account = deployer@...` en el config, ¿tus comandos `gcloud auth list` muestran a `alice@acme.io` o a `deployer@...`?
4. Un pipeline en CI configura `CLOUDSDK_CORE_PROJECT=my-project-ci`. ¿Deberia correr `gcloud config set project` tambien? ¿Por que no?
5. Borras el archivo `~/.config/gcloud/configurations/config_dev` manualmente. ¿Que ve `gcloud config configurations list` despues?

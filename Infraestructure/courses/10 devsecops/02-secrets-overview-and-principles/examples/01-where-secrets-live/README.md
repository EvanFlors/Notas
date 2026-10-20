# Ejemplo 01 — Dónde pueden vivir los secretos (7 hogares + blast radius)

> Lectura y análisis. Sin ejecución. Objetivo: fijar en memoria **los 7 hogares posibles** de un secreto y el **blast radius** asociado a cada uno.

## 1. Mapa de hogares

```
                       MENOS seguro                                     MAS seguro
blast radius: ────────────────────────────────────────────────────────────────────►

   ┌─────────┐  ┌──────────┐  ┌───────────┐  ┌───────────┐  ┌──────┐  ┌──────────┐  ┌───────┐
   │ 1. Git  │  │ 2. Env   │  │ 3. Config │  │ 4. Secret │  │5. KMS│  │6. OIDC / │  │7. HSM │
   │ (code / │  │   vars   │  │  files    │  │  manager  │  │ /HSM │  │  Workload│  │ fisico│
   │ history)│  │ long-lv  │  │ (SOPS/age)│  │ (Vault,SM)│  │      │  │  Identity│  │       │
   └─────────┘  └──────────┘  └───────────┘  └───────────┘  └──────┘  └──────────┘  └───────┘
       │             │              │              │           │           │            │
   catastrofico    alto          medio          bajo        minimo     minimo     minimo+compliance
```

- **El eje horizontal no es "coste operativo"**, es *blast radius*. KMS y OIDC son operativamente más complejos pero reducen el impacto en órdenes de magnitud.
- **La frontera entre "aceptable" y "no aceptable"** suele caer entre #3 y #4. Un `.env` en disco en producción es un puente; un secreto en Git nunca lo es.

## 2. Tabla ampliada

| # | Hogar | Ejemplo canónico | Blast radius | Cuándo tiene sentido |
|---|-------|-----------------|--------------|---------------------|
| 1 | **Git (código/historia)** | `API_KEY = "sk_fake_abc..."` hardcoded en `settings.py` | **Catastrófico** — queda en historia, caches, forks, mirrors; filtración = permanente | **Nunca.** Rotar y limpiar. |
| 2 | **Env vars long-lived** | `AWS_ACCESS_KEY_ID=AKIAFAKE...` exportado en pipeline hace 2 años | **Alto** — dumps de proceso, logs, child processes, coredumps | Puente aceptable **sólo si** son short-lived (OIDC/STS). |
| 3 | **Config files (cifrados o no)** | `secrets.enc.yaml` cifrado con SOPS+age; `.env` en disco | Alto si plain, medio si cifrado | Migración desde #1/#2 hacia #4/#6. |
| 4 | **Secret manager** | Vault KV, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault | **Bajo** — acceso auditable, scope por secreto, rotación centralizada | Default para "secretos long-lived necesarios". |
| 5 | **KMS / Transit / HSM-software** | AWS KMS CMK, GCP KMS, Vault Transit | **Mínimo** — la clave **no sale** del módulo; sólo opera sobre ella (encrypt/decrypt/sign) | Cifrado at-rest, firma de JWTs/tokens, envelope encryption. |
| 6 | **OIDC federation / Workload Identity** | GitHub Actions → AWS vía `aws-actions/configure-aws-credentials`; IRSA en EKS; WI en GKE | **Mínimo** — **no hay secret estático** | **Objetivo final** cloud+CI. |
| 7 | **HSM físico / hardware wallet** | YubiHSM, CloudHSM, YubiKey para root CA | Mínimo + cumplimiento regulatorio (FIPS 140-2/-3) | Root CA, firma de releases high-assurance. |

## 3. Flujo típico de migración (bottom-up por reducción de blast radius)

```
   #1 Git                     ─[rotar + git filter-repo]→   fuera
                                                              │
                                                              ▼
   #2 env vars long-lived     ─[mover a secret manager]→    #4
                                                              │
                                                              ▼
   #3 .env en disco           ─[reemplazar por fetch         #4
                                 a Vault/SM en arranque]→
                                                              │
                                                              ▼
   #4 secret manager          ─[federar via OIDC/WI]  →      #6
   (p.ej. AWS SM)              (apps nuevas, pipelines CI)
                                                              │
                                                              ▼
   #5 KMS                     se usa junto con #4/#6 para cifrar los VALORES
                              (envelope encryption) — complementario, no substituto.

   #6 OIDC / WI               ─[si hay compliance] →         #7 (HSM) para firmas de root
```

Observación: #5 (KMS/HSM-software) y #6 (OIDC/WI) **no se excluyen**. Un stack maduro usa WI para que las apps obtengan credenciales efímeras **y** KMS para cifrar datos sensibles en reposo con llaves que nunca salen del módulo.

## 4. "Mismo secreto, varios hogares" — el multiplicador silencioso

Un error muy común: el mismo valor termina en 3 sitios por descuido evolutivo.

```
   secret "stripe_live_key" vive hoy en:
     ├─ .env commiteado en repo privado         (hogar #1 — catastrófico)
     ├─ GitHub Actions Secret                   (hogar #2 — alto)
     ├─ AWS Secrets Manager                     (hogar #4 — bajo)
     └─ Slack #payments-ops (pinned message)    (fuera del mapa — alto)

   blast radius efectivo = max(blast radius de cada hogar) = catastrófico
```

**Regla de higiene:** cada secreto tiene **un** hogar canónico. Las demás copias son fugas latentes.

## 5. Cómo leer esto en una auditoría real

Cuando auditas un proyecto (actividad `01-audit-your-secrets`), tu columna "hogar" en el inventario **debe** elegir uno de los 7 números de arriba. Si un secreto vive en 2 hogares, abres **dos filas** y las marcas con el mismo `secret_id` — así hace visible la copia.

## 6. Puntos a repetir hasta que suenen aburridos

1. **Blast radius no es tamaño del cifrado; es *qué* puede hacer alguien que lo tenga y *durante cuánto tiempo*.**
2. **Un secreto en Git se asume comprometido para siempre** aunque el repo sea privado (forks internos, caches de CI, backups).
3. **Secret manager es bueno; Workload Identity es mejor.** Si puedes, salta directo a #6 para pipelines y pods.
4. **KMS no es un secret manager**: no guarda strings arbitrarios, opera sobre bytes (encrypt/decrypt/sign). Se complementan.

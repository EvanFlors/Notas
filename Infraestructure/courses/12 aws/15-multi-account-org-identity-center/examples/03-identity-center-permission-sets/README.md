# Ejemplo 03 — Ciclo de vida de un Permission Set

> Lectura y análisis. Sin ejecución. Objetivo: entender qué pasa **detrás** cuando creas un Permission Set en IdC y lo asignas a una cuenta.

## 1. Las piezas

```
┌─────────────────────────────────────────────────────────────────┐
│  IAM Identity Center (vive en el management account)            │
│                                                                 │
│   Users / Groups                 Permission Sets                │
│   ─────────────────              ───────────────────            │
│   - alice@acme.io                - PowerUserAccess              │
│   - bob@acme.io                  - ReadOnlyAccess               │
│   - group=platform               - Billing                      │
│   - group=developers             - BreakGlassProd (MFA+alert)   │
│                                                                 │
│                   Assignments                                   │
│                   ───────────                                   │
│   (group=platform, PS=PowerUser, OU=Workloads/Dev)              │
│   (group=platform, PS=ReadOnly,  OU=Workloads/Prod)             │
│   (user=alice,     PS=BreakGlassProd, acct=app-A-prod)          │
└──────────────────────────┬──────────────────────────────────────┘
                           │   provision
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Target account (ej: app-A-dev, 333333333333)                   │
│                                                                 │
│   IAM Role materializado automáticamente por IdC:               │
│                                                                 │
│     Role name:  AWSReservedSSO_PowerUserAccess_<16hex>          │
│     Trust:      sts:AssumeRoleWithSAML desde IdC                │
│     Permissions: adjuntadas desde el Permission Set             │
│                                                                 │
│   (NO existe un IAM user; la federación es vía SAML)            │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Qué hace cada pieza

| Pieza | Dónde vive | Qué contiene |
|-------|------------|--------------|
| **Identity source** | IdC o IdP externo (Okta/Entra ID/Google) | Usuarios y grupos. En org seria, viene de SCIM push desde el IdP. |
| **Permission Set** | IdC, en el management | Plantilla de políticas (AWS managed, customer managed, inline). Un *session duration* (1h–12h). |
| **Assignment** | IdC | Tupla (principal, PS, target). Target puede ser una cuenta o una OU. |
| **IAM Role materializado** | Cuenta destino | Rol real creado por IdC. Nombre `AWSReservedSSO_<PS>_<hash>`. Trust policy fija apuntando a IdC. |

## 3. Flujo cuando un usuario hace login

```
1. alice abre https://acme.awsapps.com/start
2. IdC redirige a su IdP corporativo (Okta/Entra ID vía SAML)
3. alice se autentica allí (MFA incluido)
4. IdC recibe la aserción SAML, mira sus grupos
5. IdC muestra a alice las cuentas donde tiene algún Permission Set asignado
6. alice elige "app-A-dev" + Permission Set "PowerUserAccess"
7. IdC llama a sts:AssumeRoleWithSAML contra el rol
   AWSReservedSSO_PowerUserAccess_<hash> en app-A-dev
8. STS devuelve credenciales temporales (1h-12h según session duration)
9. alice usa esas credenciales desde la consola o desde `aws` CLI
   (aws configure sso lo automatiza)
```

## 4. Qué pasa si cambias el Permission Set

- **Añades una policy al PS**: IdC lo marca como "needs re-provisioning". Debes hacer *provision* (manual o automatizado). Al re-provisionar, el rol materializado en cada cuenta se **actualiza** (nuevas policies attached).
- **Borras el PS**: todos los roles materializados en todas las cuentas asignadas se **borran**. Sesiones activas siguen hasta que expiren (sus credenciales STS tienen tiempo propio).
- **Editas el rol materializado a mano en una cuenta**: drift. En el siguiente *provision*, IdC **sobrescribe** tus cambios. **No lo hagas.**

## 5. Patrón de asignación: por grupo + por OU

Mal (no escala):

```
assignment(alice,  AdministratorAccess, app-A-dev)
assignment(alice,  AdministratorAccess, app-A-stg)
assignment(alice,  AdministratorAccess, app-A-prod)
assignment(bob,    AdministratorAccess, app-A-dev)
assignment(bob,    AdministratorAccess, app-A-stg)
...
```

Bien (una tupla cubre a todos y a todas las cuentas de la OU):

```
assignment(group=platform, PS=AdministratorAccess, OU=Workloads/Dev)
assignment(group=platform, PS=ReadOnlyAccess,     OU=Workloads/Prod)
```

Añadir un developer = añadirlo al grupo. Añadir una cuenta a la OU = ya tiene el rol asignado. Mantenimiento mínimo.

## 6. Catálogo mínimo de Permission Sets (sugerido)

| Nombre PS | Políticas | Session | Audiencia |
|-----------|-----------|---------|-----------|
| `AdministratorAccess` | `arn:aws:iam::aws:policy/AdministratorAccess` | 1h | SRE/Platform, solo cuentas no-prod. |
| `PowerUserAccess` | `PowerUserAccess` + inline (bloquea `iam:*Write*`) | 4h | Developers en dev/stg. |
| `ReadOnlyAccess` | `ReadOnlyAccess` | 8h | Devs en prod, QA, auditores. |
| `BillingReadOnly` | `AWSBillingReadOnlyAccess` | 8h | Finance. |
| `SecurityAuditor` | `SecurityAudit` + lectura de CloudTrail/Config | 8h | Equipo de seguridad en `audit` acct. |
| `BreakGlassProd` | `AdministratorAccess` + Condition MFA, con alerta en CloudTrail → Slack | 1h | Alias de emergencia, 2–3 personas, uso excepcional. |

## 7. Lo que NO es IdC

- **No es un IdP** (no es Okta ni Entra ID). Es un *consumer* de IdPs.
- **No es un vault de credenciales de app**. Para secrets de aplicación, usa **Secrets Manager** o **Parameter Store** (SSM).
- **No reemplaza IAM users para aplicaciones**. Las apps siguen usando IAM roles (vía IRSA/Pod Identity en EKS, instance profiles en EC2, execution roles en Lambda).

## 8. Preguntas de autocomprobación

1. Si borras el Permission Set `PowerUserAccess` en IdC, ¿qué pasa con las sesiones de los developers que ya habían hecho login hace 10 minutos?
2. Un auditor pregunta: "¿quién tiene acceso a app-A-prod y con qué permisos?". ¿Qué comando/vista le muestras?
3. ¿Por qué asignar por **grupo** y por **OU** reduce drift respecto a asignar por **usuario** y por **cuenta**?
4. En una cuenta migrada desde IAM users clásicos, ¿cómo coexisten los IAM users antiguos y los roles de IdC durante la transición?
5. Si tu IdP corporativo (Okta) cae, ¿puedes seguir entrando a AWS vía IdC? ¿Y con el usuario root de la management account?

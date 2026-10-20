# sec-02 — Lección: secretos, panorama y principios

> 12 secciones. 100 % conceptual + inventario. Prerrequisito: `sec-01`.

---

## 1. Punto de partida: por qué los secretos son el problema #1 de la supply chain

Si abres el postmortem de los incidentes más dolorosos de los últimos años — Uber (2016), Codecov (2021), CircleCI (2023), tj-actions/changed-files (2025) — y los lees en diagonal, verás la **misma frase** repetida con disfraces distintos:

> *"Un atacante obtuvo credenciales **de larga vida** con permisos **más amplios de lo necesario** y las usó durante **días o semanas** sin detección."*

Esa es la ecuación completa. Tres factores multiplicativos:

```
riesgo_real(secreto) ≈ privilegio × ventana_de_vida × probabilidad_de_fuga
```

Cada uno de los tres puede **tender a cero** si aplicas un principio concreto:

- `privilegio` → **mínimo privilegio** (scopes estrechos, roles granulares).
- `ventana_de_vida` → **short-lived > long-lived** (OIDC, STS, dynamic creds).
- `probabilidad_de_fuga` → **secret scanning + auditoría + rotación**.

Este módulo no instala nada. Instala los **principios** sobre los que luego apoyarás Vault, ESO, OIDC, Trivy y Kyverno. Si no entiendes por qué una API key en `.env` comprometida hace 6 meses es peor que una filtrada esta mañana, cualquier herramienta será pintura sobre un edificio podrido.

> **Idea clave que repetiremos:** un secreto es una **contraseña que se vuelve exponencialmente más valiosa cuanto más tiempo existe**.

---

## 2. Definición operativa: qué es un secreto y qué no

Un **secreto** es un **valor** cuya **exposición** cumple **al menos una** de estas dos condiciones:

1. **Rompe confidencialidad** de un dato protegido (p. ej. una clave de cifrado permite leer datos cifrados en reposo).
2. **Permite acción no autorizada** sobre un recurso (p. ej. una API key permite leer/escribir en un sistema externo con la identidad de la organización).

Esta definición es **conductual**, no sintáctica. No importa si el valor parece aleatorio o si vive en una variable llamada `SECRET`. Importa **qué puede hacer alguien que lo tenga**.

Corolario importante — **qué NO es un secreto**:

| Ejemplo | ¿Secreto? | Razón |
|---------|-----------|-------|
| `DATABASE_URL=postgres://app:p4ssw0rd@db/app` | **Sí** | Lleva credenciales. |
| `DATABASE_HOST=db.internal.corp` | **No** (es config sensible) | No autoriza acceso por sí sola; filtrada ayuda al atacante pero no abre la puerta. |
| `API_KEY=sk_live_abc...` | **Sí** | Autentica como la organización. |
| `FEATURE_FLAG_NEW_UI=true` | **No** | No autoriza nada. |
| Lista interna de IPs de servicios | **No** | Config sensible. Clasifícala como `internal`, no como `secret`. |
| Clave privada TLS del certificado del edge | **Sí** | Permite impersonar el servicio. |
| Clave pública del certificado | **No** | Está pensada para distribuirse. |

**Confundir "config sensible" con "secreto" tiene dos costes**: trataas config como si rotara (y gastas esfuerzo) o tratas secretos como config (y los dejas en Git). Separar las dos categorías es el primer trabajo de higiene.

---

## 3. Taxonomía por propósito

Hay cientos de nombres comerciales. Operativamente, casi todo cae en siete familias:

| Familia | Ejemplos | Qué protege | TTL típico razonable |
|---------|----------|-------------|---------------------|
| **API keys** | Stripe `sk_live_...`, GitHub PAT, OpenAI `sk-...` | Acceso a servicio SaaS | Semanas-meses (si no hay alternativa short-lived) |
| **DB credentials** | `postgres://user:pass@...` | Acceso a base de datos | Horas (dynamic) o días |
| **OAuth / JWT tokens** | access_token, refresh_token, IdP tokens | Identidad delegada | Minutos (access), semanas (refresh) |
| **Cert priv keys** | `tls.key`, mTLS client key | Impersonar el servicio | Meses-años (automatizado) |
| **SSH keys** | `id_ed25519`, deploy keys | Acceso a hosts / Git | Semanas (si rotable) o años + CA SSH |
| **Signing keys** | JWT HMAC, cosign/sigstore, GPG | Firmar artefactos / tokens | Keyless > key-based (ver `sec-09`) |
| **Encryption keys / KEKs** | KMS CMK, LUKS keys, data keys | Cifrado at-rest | Rotación anual + versioning |

Dos consecuencias prácticas:

- **El TTL depende de la familia.** No es "rotar todo cada 90 días". Es "cada familia tiene su reloj".
- **Si un secreto no encaja en ninguna familia, probablemente es config sensible, no un secreto.** O lo estás usando mal.

> **Regla:** antes de almacenar un valor como secreto, nómbralo en una de estas siete familias. Si no puedes, es síntoma.

---

## 4. Los seis anti-patrones que explican la mayoría de los incidentes

Los repites hasta que suenen aburridos, porque los vas a encontrar **todos los lunes**.

### 4.1 Secretos hardcoded en código

```python
# anti-patron
STRIPE_KEY = "sk_live_abc123def456..."
```

- Entra a Git. Entra a la **historia**. Un `git rm` **no** lo borra.
- Entra al pipeline de CI. Entra a cachés. Entra a backups.
- Un secreto que ha estado 2 minutos en un repo público se asume **permanentemente comprometido**. La única respuesta correcta es **rotar primero, limpiar segundo**.

### 4.2 Secretos en env vars de **larga vida**

Un `.env` con `AWS_ACCESS_KEY_ID=AKIA...` que lleva 3 años igual **es** un anti-patrón, aunque esté "fuera del código". Las env vars se filtran por:

- Dumps de proceso (`/proc/<pid>/environ`).
- Logs mal configurados (`print(os.environ)`).
- Child processes que heredan todo.
- Herramientas de debugging que las vuelcan.

El problema no es la variable; es la **ventana de vida**.

### 4.3 Secretos en sistemas de tickets y wikis

Jira, Linear, Confluence, Notion. Alguien pega `password: pepito123` en un ticket "para que lo tenga el nuevo". Ese ticket:

- Es indexable por búsqueda.
- Es visible a cualquier integración (bots, plugins, OAuth apps instaladas).
- No tiene rotación ni auditoría de lectura.

### 4.4 Secretos en Slack / Teams / Discord

El canal `#dev-ops` con un `curl ... -H "Authorization: Bearer eyJ..."` para debuggear producción. Ese token:

- Queda indexado para siempre en la búsqueda.
- Es visible a todos los miembros del workspace (en Slack free, 90 días; en paid, para siempre).
- Es visible a cualquier app con `channels:history`.

### 4.5 Secretos comprometidos **y rotados**, pero no **limpiados de la historia**

Casi un anti-patrón inverso: la gente **sabe** que debe rotar, pero cree que "borrar el archivo" es suficiente. No lo es. Git conserva el commit. `git filter-repo` / BFG limpian la historia, pero **sólo** tiene sentido hacerlo **después** de rotar, porque el secreto ya fue público. (Esto lo verás con herramientas reales en `sec-04`.)

### 4.6 Secretos "temporales" que se vuelven permanentes

El clásico: alguien crea una PAT con scope `repo:*` "para probar un script" y nunca la revoca. Dos años después el repo del script está archivado, el autor dejó la empresa, y la PAT sigue viva. **Toda credencial sin TTL es, por construcción, un bug.**

---

## 5. Los principios irrenunciables (los que ganarás repitiendo)

Cinco principios. Si tu plataforma viola alguno, estás pagando riesgo que podrías no pagar.

### 5.1 Rotación

Toda credencial tiene **TTL**. "Pensar en rotarla" **no** es rotar. **Rotación automática** o es ritualista (nadie la hace cuando toca).

- Dynamic creds (Vault): TTL es la rotación.
- Short-lived (OIDC, STS): el token caduca; se emite otro.
- Long-lived manual: cron + runbook + aviso + fallback. Caro.

### 5.2 Mínimo privilegio

Un secreto no es "acceso". Es acceso **con un scope**. `AdministratorAccess` para un script que sólo lee S3 es como darle a un repartidor la llave maestra del edificio. Define scopes **antes** de generar el secreto.

### 5.3 Auditoría (quién leyó qué, cuándo)

Si tu secret manager no registra lecturas, no sabes **qué filtró** un atacante tras un incidente. Vault, AWS Secrets Manager, GCP Secret Manager y Azure Key Vault **todos** emiten eventos de acceso. **Actívalos** y envíalos al SIEM.

### 5.4 Detección de uso anómalo

Una API key normalmente se usa desde `prod-us-east`. Si de repente aparece una llamada desde `AS12345` en Lagos a las 03:14, eso **no es rotación**, es **detección**. Las dos son complementarias.

### 5.5 Separation of duties (SoD)

Quien escribe código **no debería** poder leer la credencial de producción. Quien aprueba acceso a producción **no debería** poder empujar código. La misma persona haciendo las dos cosas = una sola credencial comprometida = ownage total.

> El **cuadro mental** útil: cada principio reduce una variable distinta de `privilegio × ventana × probabilidad`. Instalar sólo uno (p. ej. "rotamos cada 90 días") sin los otros deja el otro factor en 1.0 — y 1.0 × algo grande sigue siendo algo grande.

---

## 6. Short-lived > long-lived: la ganancia individual más grande

Si tuvieras que elegir **una** cosa para reducir el blast radius de los secretos de tu plataforma, sería ésta: **eliminar los long-lived**.

### 6.1 Por qué un long-lived es exponencialmente peor

Modelo mental: probabilidad acumulada de fuga.

```
P(leak_antes_de_t) = 1 - (1 - p_diaria) ^ t
```

Con `p_diaria = 0.001` (un chance en mil de que se filtre hoy):

- TTL 15 min  → ~0.00001 % de probabilidad de que ESE token se filtre antes de caducar.
- TTL 1 día   → 0.1 %.
- TTL 90 días → ~8.6 %.
- TTL 1 año   → ~30 %.
- TTL 3 años  → ~66 %.

Y una vez filtrado, **el impacto escala con lo que ese secreto puede hacer**. Un token de 15 min con scope `read:artifact-metadata` en el peor caso te hace perder los próximos 15 min de metadata; una PAT de 3 años con `repo:*` + `admin:org` te hace perder la organización.

### 6.2 Mecanismos para short-lived (visión; se profundiza en `sec-09` y `sec-13`)

- **OIDC federation** (GitHub Actions → AWS/GCP/Azure/HashiCorp Cloud): el runner intercambia su JWT de identidad por credenciales **efímeras** del cloud. **Sin secret en GitHub**.
- **Workload Identity** (IRSA en EKS, Workload Identity Federation en GKE, Managed Identity en AKS): el **Pod es** un principal cloud; el SDK negocia credenciales short-lived sin ningún secreto montado.
- **STS AssumeRole / `sts:GetCallerIdentity`**: el servicio asume un rol a demanda; las credenciales viven 15 min a 12 h.
- **Vault dynamic secrets**: Vault crea un usuario DB on-demand, con TTL; cuando vence, Vault lo revoca.
- **Keyless signing (Sigstore / cosign)**: el certificado de firma vale **minutos**, atado al OIDC claim del builder. (Ver `sec-09`.)

> **Idea clave:** cada vez que ves un `*_SECRET` o `*_KEY` largo en una variable de entorno de producción, pregúntate: **¿existe un mecanismo short-lived equivalente?** Casi siempre sí.

---

## 7. Dónde pueden vivir los secretos (los 7 hogares)

Un mismo secreto puede vivir en varios sitios a la vez — y eso **también** es un problema (más superficie, más puntos de fuga).

| Hogar | Qué es | Blast radius si se filtra | Cuándo tiene sentido |
|-------|--------|---------------------------|----------------------|
| **1. Código / Git** | hardcoded en fuentes | **Catastrófico** (historia pública, caches, forks) | **Nunca.** |
| **2. Env vars (CI / runtime)** | `AWS_ACCESS_KEY_ID` exportado | Alto (dumps, logs, child processes) | OK **si** son short-lived (OIDC/STS). Malo si long-lived. |
| **3. Config files (encriptados o no)** | `.env`, `secrets.yaml` | Alto si plain; medio si cifrado (SOPS/age/sealed-secrets) | Puente aceptable durante migración. |
| **4. Secret manager** | AWS Secrets Manager, GCP SM, Azure KV, Vault KV | Bajo (acceso auditable + least privilege) | **Default** para secretos long-lived "necesarios". |
| **5. KMS / HSM** | AWS KMS, GCP KMS, HashiCorp Transit | Mínimo (la clave **no sale** del módulo) | Cifrado de datos, firma de tokens, envelope encryption. |
| **6. Workload Identity / OIDC** | IRSA, GKE WI, GH Actions OIDC | **Mínimo** (no hay secreto estático) | **Objetivo final** para cloud + CI. |
| **7. HSM físico / hardware wallet** | YubiHSM, CloudHSM, YubiKey | Mínimo + requisitos regulatorios | Firmado de root CA, high-assurance signing. |

Dos lecturas rápidas:

- La columna **blast radius** no es monotónica con el coste operativo: un secret manager es barato y reduce muchísimo el riesgo frente a env vars; subir a OIDC/WI es más esfuerzo pero elimina el secret estático.
- **La migración típica** va de abajo hacia arriba en la tabla: `código → env vars → config cifrado → secret manager → workload identity`. Cada paso compra una reducción de blast radius.

---

## 8. Blast radius: la métrica que importa

Para cualquier secreto, el **blast radius** es la respuesta honesta a tres preguntas:

1. **Scope**: ¿qué puede hacer alguien que lo tenga? (lectura/escritura, en qué recursos, con qué cuota).
2. **Ventana**: ¿cuántas horas/días/meses está vivo?
3. **Alcance**: ¿cuántos sistemas se contagian? (¿puede moverse lateralmente? ¿puede re-encadenar privilegios?).

Un ejemplo concreto (compararás ambos en el ejemplo 02):

| Secreto | Scope | Ventana | Alcance | Blast radius |
|---------|-------|---------|---------|-------------|
| AWS access key `AKIA...` con `AdministratorAccess` desde laptop de un dev | **Todo** | 2 años (nadie rota) | **Cuenta cloud entera** | **Extremo** |
| Token OIDC de GH Actions con rol `s3-ci-upload` | `s3:PutObject` en 1 bucket | **15 min** | 1 bucket | **Mínimo** |

Ambos "autentican como la organización en AWS". La diferencia práctica es de **órdenes de magnitud**.

> **Regla de bolsillo:** si no puedes expresar el blast radius de un secreto en una frase, no sabes lo suficiente sobre ese secreto para operarlo con seguridad.

---

## 9. Rotación: qué es, qué no es, y por qué duele cuando se hace mal

**Rotación** = sustituir el valor de un secreto por uno nuevo **sin interrumpir** servicio y **invalidando** el anterior.

Tres propiedades que deben cumplirse siempre:

1. **Zero downtime**: la app no se cae durante el cambio.
2. **No overlap peligroso**: la ventana en la que ambos valores (viejo y nuevo) son válidos **debe acabar en revocación explícita** del viejo. "Dejarlos ambos activos indefinidamente" **no** es rotación.
3. **Auditable**: queda registro de quién la ejecutó y cuándo.

Patrones comunes:

- **Dual-write + grace window**: el productor genera `v2`, se despliega leyendo `v1 OR v2`, se despliega escribiendo con `v2`, se revoca `v1`. Patrón para claves de cifrado y signing keys.
- **Blue/green por conexión**: el pool de conexiones DB se vacía con `v1` mientras uno nuevo abre con `v2`. Patrón para DB creds.
- **Reemplazo atómico**: el secret manager publica `v2`, los pods hacen rolling restart y leen `v2`. Patrón para API keys.
- **TTL expiration (ideal)**: no hay rotación explícita; el token vence y se renueva. OIDC, STS, dynamic creds. **El patrón que querrás** siempre que puedas.

**Rotación ≠ revocación.** Revocar invalida; rotar sustituye. Un incidente real necesita **las dos**: revocas el secreto expuesto y rotas el nuevo. Si sólo rotas, el viejo sigue siendo válido en ventanas donde dual-write no caducó.

---

## 10. Separation of duties (SoD) aplicada a secretos

El principio es viejo (contabilidad lo lleva usando siglos): **quien autoriza una cosa no debe poder ejecutarla**. En plataformas, se traduce a tres roles canónicos:

- **Owner del secreto** (quién decide que existe, quién puede leerlo, con qué TTL).
- **Consumer del secreto** (quién lo **lee** en tiempo de ejecución; típicamente una app o pipeline con un principal propio).
- **Approver de acceso a producción** (quién firma el PR que agrega una app como `consumer`).

Si una misma persona junta ≥2 roles, has anulado el principio.

Implicaciones prácticas:

- Un desarrollador **no** debería poder leer secretos de prod desde su laptop. Puede leer los de `staging` con su identidad personal; los de prod sólo los lee el pipeline o el servicio.
- El bot que renueva secretos debe tener permiso para **escribir** (nuevo valor) pero no para **leer** (eso le corresponde al consumer autenticado).
- El `break-glass` manual (ver §11) debe ser **ruidoso**: múltiples aprobadores, log explícito, revisión posterior.

Esto no es ceremonia: cada rol compartido es un single point of compromise.

---

## 11. Break-glass: el caso extremo que necesitas haber ensayado

**Break-glass** = procedimiento para **acceder a un secreto crítico** cuando el canal normal está roto (p. ej. Vault caído, OIDC roto, cloud auth con outage). Características:

- **Ruidoso por diseño**: dispara alerta inmediata, requiere ≥2 personas, deja registro inmutable.
- **TTL cortísimo**: la credencial break-glass vale minutos, no días.
- **Revisión obligatoria post-mortem**: cada uso se revisa (fue legítimo o fue un incidente).
- **Separado del flujo normal**: su mecanismo no comparte superficie con el que acaba de fallar (no uses OIDC para rescatar OIDC).

Patrón habitual: una PAT/key custodiada en un sobre sellado (literal o KMS-wrapped) + 2-factor humano + post-use rotation automática.

> **Si no tienes break-glass ensayado**, cuando lo necesites — y lo necesitarás — alguien improvisará y creará justo el long-lived que llevabas 2 años evitando. Ensáyalo. Al menos una vez.

---

## 12. Checklist operativo: por dónde empezar en un proyecto real

El orden importa — es el que maximiza "riesgo eliminado por hora invertida".

1. **Inventario** (actividad `01` de este módulo).
   - ¿Qué secretos existen? ¿Dónde viven? ¿Quién es el owner? ¿Cuál fue el último uso?
2. **Clasificación** por familia (§3).
   - API key, DB cred, cert, SSH, JWT signing, encryption, OAuth.
3. **Blast radius score** por secreto (§8).
   - Scope + ventana + alcance.
4. **Rotación forzosa** de los que estén en Git / Slack / tickets.
   - Primero **rotar**, luego limpiar historia (si aplica, con `git filter-repo`; se verá en `sec-04`).
5. **Mover a secret manager** los que estén en env vars long-lived.
   - Puente aceptable. No es el objetivo final, es el siguiente paso.
6. **Migrar a short-lived** (OIDC/WI/STS) todos los que puedan.
   - La ganancia individual más grande. Se hace servicio por servicio.
7. **Policy de rotación por tipo** (actividad `02`).
   - ADR escrito con TTL razonado por familia y proceso de break-glass.
8. **Secret scanning** en pipeline (se instala en `sec-04`).
   - Para que no se caiga **el próximo** por regresión.
9. **Auditoría + anomaly detection** encendidas (SIEM, GuardDuty, Cloud Audit Logs).
10. **Review trimestral** del inventario y de las excepciones.

> El error más común es intentar saltar al paso 6 directamente. **No funciona.** Sin inventario (paso 1) no sabes qué estás migrando; sin blast radius (paso 3) no sabes qué migrar primero; sin policy (paso 7) la migración se revierte sola.

---

### Lo que te llevas de este módulo

- Un secreto es un **valor con poder**; su riesgo es `privilegio × ventana × probabilidad`.
- Los **anti-patrones** son los sospechosos habituales de los incidentes; aprende a verlos a 10 metros.
- La ganancia **individual más grande** es eliminar long-lived — y hay mecanismos reales (OIDC, WI, STS, Vault dynamic) para hacerlo.
- Antes de instalar nada, **inventaría y clasifica** (actividad 01). Después escribe la **policy** (actividad 02). Las herramientas llegan en `sec-04` y `sec-13`.

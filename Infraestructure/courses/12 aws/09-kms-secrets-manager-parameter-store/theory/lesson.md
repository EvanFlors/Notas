# Lección — KMS, Secrets Manager y SSM Parameter Store

> Esta lección es la columna vertebral del módulo. Léela entera antes de hacer las actividades.

## 1. ¿Por qué estos tres servicios juntos?

Los tres resuelven **matices distintos del mismo problema**: dejar de meter secretos y claves en el código, en el repo, en variables de entorno sin cifrar o en S3 "con un bucket privado" (que mañana alguien hace público por error).

- **KMS** gestiona **claves criptográficas**. No almacena tus secretos, cifra las cosas que almacenan **otros**.
- **Secrets Manager** gestiona **secretos rotables** (credenciales, API tokens, certificados cortos). Incluye versionado y rotación automática.
- **SSM Parameter Store** gestiona **configuración**. Puede ser texto plano (`String`) o cifrado con KMS (`SecureString`). Es gratis para el tier *standard* y escala muchísimo mejor cuando el "secreto" en realidad es *config* no sensible.

La decisión diaria no es "usar los tres", es **"qué dato pongo en cuál"**. Esa es la evaluación central del módulo.

## 2. KMS en 60 segundos

Una **CMK** (Customer Master Key, hoy oficialmente *KMS key*) es la pieza central. Tres tipos:

| Tipo | ¿Quién la crea? | ¿Quién la rota? | ¿Puedes borrarla? | Costo |
|------|-----------------|------------------|-------------------|-------|
| **AWS-managed** (`aws/<service>`) | AWS | AWS (anual, obligatorio) | No | 0 |
| **Customer-managed** | Tú | Opcional (anual, flag) | Sí (con *schedule* de 7–30 días) | $1/mes por key + API calls |
| **Customer-provided** (BYOK / External Key Store — XKS) | Tú (importado o HSM externo) | Tú (si importada) | Sí | igual + overhead HSM |

Para la mayoría de workloads, **customer-managed** es la opción por defecto en producción. AWS-managed es útil para "quiero cifrado en reposo mínimo sin pensarlo" (p. ej. S3 default encryption en entornos de scratch).

### 2.1 Operaciones básicas

- `kms:GenerateDataKey` → te devuelve una **data key** simétrica en texto plano **y** cifrada con la CMK.
- `kms:Encrypt(plaintext, KeyId)` → cifra algo pequeño (≤ 4 KB).
- `kms:Decrypt(ciphertext)` → descifra; AWS deduce la CMK del propio ciphertext.
- `kms:ReEncrypt` → cambia de CMK sin pasar por texto plano en tu lado.

Cuesta por API call, no por byte: por eso **envelope encryption** es el patrón idiomático.

## 3. Envelope encryption, explicado como corresponde

El error típico de alguien que llega nuevo a KMS: "voy a cifrar mi archivo de 50 MB con `kms:Encrypt`". **No funciona**: KMS rechaza payloads > 4 KB.

El patrón real:

```
          ┌──────────────────────────────────────────────┐
          │  1. GenerateDataKey(KeyId=CMK)               │
          │     returns:                                  │
          │       Plaintext        (32 bytes AES key)     │
          │       CiphertextBlob   (misma key cifrada)    │
          └──────────────────────────────────────────────┘
                           │
                           ▼
          ┌──────────────────────────────────────────────┐
          │  2. En tu proceso (local, sin red):           │
          │     ciphertext = AES_GCM(Plaintext, payload)  │
          │     wipe(Plaintext)   ← crítico               │
          └──────────────────────────────────────────────┘
                           │
                           ▼
          ┌──────────────────────────────────────────────┐
          │  3. Almacenas:                                │
          │       CiphertextBlob   (data key cifrada)     │
          │       ciphertext       (payload cifrado)      │
          │       nonce + tag      (del AES-GCM)          │
          └──────────────────────────────────────────────┘

   Al leer:
     a. kms:Decrypt(CiphertextBlob) → Plaintext (data key)
     b. AES_GCM_decrypt(Plaintext, ciphertext) → payload original
     c. wipe(Plaintext)
```

Por qué importa:

- **1 llamada a KMS por payload** (en vez de miles). Costo y latencia bajos y constantes.
- La data key en texto plano **nunca** sale de tu proceso.
- Puedes rotar la CMK sin recifrar todos los payloads: la nueva CMK solo tiene que ser capaz de descifrar las data keys viejas (o re-wrap con `kms:ReEncrypt`).

Esto es exactamente lo que hacen S3 SSE-KMS, EBS encryption, RDS encryption y Secrets Manager por debajo.

## 4. Key policy vs IAM policy — el error que más veces vas a cometer

Reglas:

1. Una CMK **siempre** tiene una key policy. No es opcional.
2. **La key policy es la fuente primaria de autoridad.** Una IAM policy que diga `kms:Decrypt *` **no abre nada** si la key policy no delega en IAM.
3. La delegación en IAM se hace con:

   ```json
   {
     "Sid": "EnableIAMUserPermissions",
     "Effect": "Allow",
     "Principal": { "AWS": "arn:aws:iam::<ACCT_ID>:root" },
     "Action": "kms:*",
     "Resource": "*"
   }
   ```

   Esto no da acceso a nadie en concreto: dice "las IAM policies de esta cuenta pueden usarse para autorizar operaciones sobre esta key". Luego la IAM policy del rol concede efectivamente el permiso.

4. **Principal de servicio ≠ principal de rol.** Si quieres que Secrets Manager pueda usar la CMK para cifrar secretos:

   ```json
   {
     "Sid": "AllowSecretsManagerUse",
     "Effect": "Allow",
     "Principal": { "Service": "secretsmanager.amazonaws.com" },
     "Action": ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"],
     "Resource": "*",
     "Condition": {
       "StringEquals": {
         "kms:ViaService": "secretsmanager.<region>.amazonaws.com",
         "kms:CallerAccount": "<ACCT_ID>"
       }
     }
   }
   ```

   La `kms:ViaService` + `kms:CallerAccount` restringe el uso a llamadas que vengan **a través de Secrets Manager** y **desde tu cuenta**. Sin esas condiciones, cualquier otra integración podría usar la CMK en tu nombre.

Confusión típica: *"mi rol tiene `kms:Decrypt` en IAM pero sigue dando AccessDenied."* Causa casi siempre: la key policy no delega en IAM **o** no incluye explícitamente al rol como principal.

## 5. Rotación de CMK

- `EnableKeyRotation` → AWS rota **anualmente** el material criptográfico interno.
- La **key ID y el ARN no cambian**, por lo que todo lo cifrado antes sigue descifrándose: AWS mantiene las versiones viejas.
- La rotación es **transparente para el consumidor**. No hay que hacer nada en la app.

Lo que **no** hace: no cambia la key policy, no reemite tus data keys cifradas, no rota tus secretos. Rotación de la **CMK** ≠ rotación del **secreto**.

## 6. Multi-Region keys

Un patrón reciente: una **primary key** en `us-east-1` y **replicas** en otras regiones. Comparten material criptográfico, pero cada replica tiene su propia policy y su propia administración regional. Útil para DR y para servicios globales (p. ej. CloudFront + S3 con contenido cifrado accesible desde Lambda@Edge en varias regiones).

Trampa: la replica **no** es un backup — es la misma key en otra región. Si borras la primary programáticamente, destruye todas las replicas si no las promueves antes.

## 7. Secrets Manager

### 7.1 Modelo de datos

- Un **secret** tiene **versiones**. Cada versión tiene una o varias **staging labels**: `AWSCURRENT`, `AWSPREVIOUS`, `AWSPENDING`.
- La app resuelve siempre `AWSCURRENT`. El rotator mueve labels.
- El secret se cifra con una CMK (puede ser `aws/secretsmanager` o una propia).

### 7.2 Rotación — el ciclo de 4 pasos

Cuando habilitas rotación, Secrets Manager invoca una **Lambda rotator** que debe implementar cuatro pasos, en este orden, para una versión etiquetada `AWSPENDING`:

1. **createSecret**: genera un nuevo valor (nueva password), lo guarda como `AWSPENDING`.
2. **setSecret**: aplica el nuevo valor en el sistema destino (p. ej. `ALTER USER ... IDENTIFIED BY ...` en RDS). **Mantiene** la password vieja operativa.
3. **testSecret**: abre una conexión con la nueva credencial. Si falla, no se avanza (y la vieja sigue viva: nadie se queda fuera).
4. **finishSecret**: promueve `AWSPENDING` a `AWSCURRENT`. La anterior `AWSCURRENT` pasa a `AWSPREVIOUS`.

Durante los pasos 1–3, hay dos credenciales válidas al mismo tiempo. Esto es intencional: **la ventana de rotación no tira a nadie**. Después del paso 4, la vieja sigue existiendo como `AWSPREVIOUS` por si una app aún tiene la cadena en memoria y necesita reconectar en los próximos segundos.

Para RDS/Redshift/DocumentDB, AWS provee templates oficiales de la Lambda rotator — rara vez hay que escribir una desde cero. Las variantes importantes son:

- **Single-user**: la misma cuenta de DB rota su propia password. Breve ventana donde el rotator usa la credencial vieja para cambiar a la nueva.
- **Multi-user (alternating)**: dos cuentas (`app_a`, `app_b`) alternan. Es más seguro y evita colisiones; preferido para prod.

### 7.3 Replicación

Puedes replicar un secret a N regiones. Cada región tiene su propia CMK (o reutiliza `aws/secretsmanager`). La rotación en la región primaria se propaga.

### 7.4 Costo

~$0.40 USD/mes por secret + API calls. **Parece poco** hasta que creas 500 secrets por despliegue efímero. Para config no sensible, siempre Parameter Store.

## 8. SSM Parameter Store

### 8.1 Tiers

| | **Standard** | **Advanced** |
|---|---|---|
| Tamaño por parámetro | 4 KB | 8 KB |
| Parameter policies (TTL, expiration notification) | No | Sí |
| Throughput | 40 TPS | 10 000 TPS |
| Costo | $0 | $0.05/mes por parámetro + API calls |

Para 99 % de los casos: *standard* es suficiente.

### 8.2 Tipos

- **String** — texto plano.
- **StringList** — CSV.
- **SecureString** — cifrado con KMS. Al crear, especificas `KeyId`; al leer, pasas `WithDecryption=True`.

### 8.3 Jerarquía por path

Convención idiomática:

```
/app/prod/db/host
/app/prod/db/port
/app/prod/features/new-checkout
/app/stg/db/host
/app/dev/db/host
```

Permite:

- `GetParametersByPath(Path="/app/prod/", Recursive=True)` → lee todo el entorno prod de golpe.
- IAM resource con wildcard: `arn:aws:ssm:<region>:<acct>:parameter/app/prod/*`.

## 9. Criterio: Secrets Manager vs Parameter Store

Pregúntate, en este orden:

1. **¿Es una credencial que debe rotarse?** → Secrets Manager.
2. **¿Lo lee algo que necesita rotación integrada (RDS, Redshift)?** → Secrets Manager.
3. **¿Es config o un endpoint fijo?** → Parameter Store `String`.
4. **¿Es un valor sensible pero no rotable (p. ej. un token OAuth que caduca y refrescas por otro lado)?** → Parameter Store `SecureString` con tu CMK.
5. **¿Tienes muchos valores pequeños (feature flags, defaults)?** → Parameter Store (costo).

Tabla de decisión aplicada a casos típicos:

| Ítem | ¿Dónde? | Por qué |
|------|---------|---------|
| Password del master de RDS | Secrets Manager | Rotación integrada 4-pasos con Lambda template oficial. |
| API token de un proveedor que **no** rota automáticamente | Parameter Store `SecureString` | Es sensible pero no hay valor en pagar por rotación que no sucede. |
| Endpoint del broker Kafka interno | Parameter Store `String` | Config, no secreto. |
| Lista de feature flags activos | Parameter Store `StringList` o `String` JSON | Volumen alto, no sensible. |
| Private key de firma JWT (RS256) | Secrets Manager | Es rotable (cada 90 días), hay que versionar `AWSCURRENT`/`AWSPREVIOUS` para que tokens firmados con la anterior sigan verificándose durante la ventana. |

## 10. Patrones y antipatrones

**Patrones**

- Siempre consumir desde la app vía **IAM role** (task role en ECS, instance profile en EC2, IRSA/Pod Identity en EKS). Nunca access keys en env vars.
- Cachear el resultado unos minutos en el proceso (p. ej. 300 s) para no inundar Secrets Manager en servicios de alto QPS.
- Enlazar `kms:ViaService` + `kms:CallerAccount` en toda key policy que delegue a un servicio AWS.
- Nomenclatura por path (`/app/<env>/<component>/<key>`) con IAM wildcards por path.

**Antipatrones**

- `kms:Decrypt *` en una IAM policy sin pensar qué CMK autoriza qué cosa.
- Guardar un secreto largo (`.pem` entero) en Parameter Store standard: se corta en 4 KB.
- Rotar la **CMK** y asumir que eso rota los secretos (son cosas distintas).
- Habilitar rotación de Secrets Manager en el mismo despliegue en que creas el secret pero sin probar la Lambda rotator en un entorno aislado: te puedes quedar fuera de prod si el `testSecret` del template oficial no está adaptado a tu red.

## 11. Qué sigue y cómo encaja con el resto

- `aws-10` (ECS/Fargate) consumirá estos secretos con **task role** y los inyectará como env vars (vía `secrets` en la task definition) o leyéndolos desde la app con `boto3`.
- `aws-11` (EKS) hace lo mismo con **IRSA/Pod Identity** y el *external-secrets operator*.
- `aws-12` (observabilidad) añade CloudTrail para auditar `kms:Decrypt` y `GetSecretValue`.
- `aws-14` (serverless) reutiliza patrones de rotación para Lambda custom.

El módulo siguiente es `aws-10`. Antes de pasar, completa las dos actividades y revisa los validadores en verde.

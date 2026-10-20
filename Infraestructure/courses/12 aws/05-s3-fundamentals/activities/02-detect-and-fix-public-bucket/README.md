# Actividad 02 — Detectar y arreglar un bucket S3 publico

## 1. Identificacion

- **ID:** `aws-05-02-detect-and-fix-public-bucket`
- **Tecnologia:** `aws`
- **Modulo:** `aws-05-s3-fundamentals`
- **Dificultad:** beginner
- **Duracion estimada:** 40–60 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Te asignan auditar un bucket llamado `legacy-marketing-assets-us-east-1` heredado de un equipo que ya no existe. Lo encontraste en un reporte de **S3 Public Access** rojo. Antes de aplicar cambios ciegos, el requerimiento es:

> El bucket **debe** seguir sirviendo las imagenes de `/public/campaigns/*` que estan embebidas en el sitio marketing publico `https://www.acme.com`. **Todo lo demas** debe estar privado y los defaults deben ser sanos.

Tu entregable es un documento `AUDIT.md` con hallazgos + los JSON corregidos aplicables. Esta actividad es **puramente de analisis**: no provisiona nada; solo lees los artefactos que te damos en `starter/` y produces los corregidos.

## 3. Objetivos

Al terminar deberias poder:

- Leer una configuracion de bucket S3 y detectar los puntos **concretos** por los que es publico.
- Proponer una **bucket policy minima** que mantenga el uso legitimo (CDN publico sobre `/public/campaigns/*`) sin exponer el resto.
- Proponer un **Block Public Access** correcto para este caso.
- Explicar por que `BucketOwnerEnforced` + policy > ACLs.
- Articular los **riesgos residuales** que quedan incluso tras la correccion (p. ej. objetos sensibles bajo `/public/` que ya pueden haberse indexado).

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` §5 (BPA), §6 (policies vs ACLs), §10 (presigned).
- Herramientas: `python3` para validar JSON. Nada mas.

**Costos**: 0.

## 5. Material entregado

En `starter/` tienes:

- `bucket-config.json` — snapshot JSON de la configuracion actual del bucket (BPA, ownership, acl, versioning).
- `bucket-policy-current.json` — la bucket policy que esta aplicada hoy.
- `object-acl-sample.json` — una ACL de objeto de ejemplo (una imagen de campaign) que esta `public-read`.

## 6. Instrucciones

### 6.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-05-audit
cp <ruta-repo>/courses/aws/05-s3-fundamentals/activities/02-detect-and-fix-public-bucket/starter/*.json \
   /tmp/aws-05-audit/
cd /tmp/aws-05-audit
```

### 6.2 Leer y comprender los artefactos

Dedica 10 minutos a leer los 3 JSON antes de escribir nada. Identifica:

- ¿Que settings de **BPA** estan en `false`?
- ¿Que **ownership** tiene el bucket? ¿Permite ACLs?
- La **policy actual** tiene `Principal: "*"`. ¿Sobre que `Resource`? ¿Con que condiciones?
- El objeto de ejemplo tiene ACL `public-read`. ¿Que implica combinado con la policy?

### 6.3 Escribir `AUDIT.md`

Produce `/tmp/aws-05-audit/AUDIT.md` con **tres secciones**:

#### Seccion A — Hallazgos (al menos 4)

Formato numerado. Para cada hallazgo:

- **Qué**: la configuracion concreta que falla.
- **Dónde**: fichero + ruta JSON (p. ej. `bucket-policy-current.json → Statement[0].Principal`).
- **Riesgo**: que puede explotarse.
- **Severidad**: alta / media / baja (justifica).

#### Seccion B — Correcciones propuestas

Lista numerada. Para cada correccion:

- **Qué** cambias.
- **Por qué** la minima necesaria (no sobrecorrijas).
- **Impacto** en el uso legitimo del bucket (recuerda: `/public/campaigns/*` debe seguir sirviendo).

Y referencia los dos ficheros JSON que entregas:

- **`policy-fixed.json`**: bucket policy nueva.
- **`bpa-fixed.json`**: configuracion `PublicAccessBlockConfiguration` nueva.

#### Seccion C — Riesgos residuales

Al menos 3 cosas que **siguen** siendo riesgo despues de aplicar tus correcciones (p. ej. objetos ya indexados por buscadores; cache de CDN con contenido viejo; logs historicos que registraron accesos).

### 6.4 Escribir los JSON corregidos

**`/tmp/aws-05-audit/policy-fixed.json`** debe:

- Tener `Version = "2012-10-17"`.
- Tener al menos un `Statement` con `Effect = Deny` y condicion `aws:SecureTransport = false` sobre `s3:*`.
- Tener al menos un `Statement` con `Effect = Allow` sobre `s3:GetObject` **restringido** al prefijo publico legitimo (p. ej. `arn:aws:s3:::legacy-marketing-assets-us-east-1/public/campaigns/*`), **no** sobre el bucket entero.
- Evitar `Action: "s3:*"` en `Allow`.

**`/tmp/aws-05-audit/bpa-fixed.json`** debe:

- Tener `PublicAccessBlockConfiguration` con `BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets` todos **`true`**.

> **Nota:** aunque el requerimiento es "seguir sirviendo publico `/public/campaigns/*`", el patron correcto moderno es **CloudFront + OAC** con el bucket privado (BPA 4/4 `true`). Para mantener compatible el ejemplo, los 4 BPA en `true` **no** rompen una policy publica aplicada **antes** de habilitar BPA, pero **si** rechazarian una nueva policy publica. En `AUDIT.md` discute esta tension y explica la ruta de migracion (poner CloudFront delante, borrar statement publico de la policy).

### 6.5 Reflexion escrita

Al final de `AUDIT.md` añade una seccion `## Preguntas` con respuestas breves a:

1. ¿Por que `BlockPublicPolicy = true` no "rompe" automaticamente una policy publica ya existente?
2. ¿Que ganas con `BucketOwnerEnforced` frente a tener ACLs activas con bucket owner mapeado?
3. Si el bucket fuera **nuevo** hoy y quisieras servir `/public/campaigns/*` publicamente, ¿que patron propondrias y por que?

## 7. Resultado esperado

- `AUDIT.md` con las secciones A, B, C y Preguntas.
- `policy-fixed.json` y `bpa-fixed.json` validos estructuralmente.
- `bash tests/validate.sh /tmp/aws-05-audit` sale en verde.

## 8. Criterios de aceptacion

- **Funcional**: validador en verde.
- **Calidad**: cada hallazgo cita la ruta JSON concreta.
- **Minimalidad**: la policy corregida **no** usa `Action: "s3:*"` en `Allow` y restringe por prefijo.
- **Honestidad**: la seccion de riesgos residuales reconoce que una correccion de policy no "des-indexa" lo que ya se filtro.

## 9. Validacion

```bash
bash tests/validate.sh /tmp/aws-05-audit
```

El validador:

1. Comprueba presencia de `AUDIT.md`, `policy-fixed.json`, `bpa-fixed.json`.
2. Verifica estructura minima de ambos JSON con Python.
3. Confirma que la policy corregida **no** contiene `Allow` con `Action` que incluya `s3:*` ni `Principal: "*"` sin condicion de IP/VPC/aws:SourceAccount.
4. Confirma que el BPA tiene los 4 flags en `true`.
5. Comprueba que `AUDIT.md` tiene las secciones y las palabras clave esperadas.

## 10. Extensiones

- Escribe tambien `cloudfront-plan.md` esbozando como pondrias CloudFront + OAC delante del bucket y como quedaria la nueva policy (que solo deja entrar al **service principal** `cloudfront.amazonaws.com` con `aws:SourceArn` de la distribucion).
- Dibuja un diagrama ASCII antes/despues.
- Añade una tabla "quien pierde acceso" para dar visibilidad al cambio.

## 11. Limpieza

```bash
rm -rf /tmp/aws-05-audit
```

No hay procesos ni contenedores.

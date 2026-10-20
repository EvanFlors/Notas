# Actividad 01 — Redactar un baseline de SCPs para una OU "prod"

## 1. Identificación

- **ID:** `aws-06-01-write-scp-baseline`
- **Tecnología:** `aws`
- **Módulo:** `aws-06-iam-advanced`
- **Dificultad:** intermediate
- **Duración estimada:** 50–60 min
- **Tipo:** independent (no depende de la actividad 02)

## 2. Contexto

Eres el responsable de seguridad de una organización AWS. La OU `prod` contiene todas las cuentas de producción. El objetivo del baseline es que **ni siquiera un admin de cuenta** pueda:

1. Operar en regiones que no están en la lista blanca (compliance).
2. Apagar los servicios de auditoría (CloudTrail, Config) — el equipo de seguridad necesita saber qué pasó siempre.
3. Ejecutar operaciones destructivas sobre buckets S3 o IAM users sin MFA (defensa contra access keys filtradas).

El entregable son **tres SCPs** en JSON + un documento `BASELINE.md` que explique **por qué** cada SCP está así y qué ataque previene.

**No** se aplica nada en AWS. La validación es **estructural**: `jq` verifica la forma de las policies.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Explicar por qué `NotAction` en una SCP de deny-region es la mejor forma de excluir servicios globales.
- Escribir una SCP que combine `StringEquals` + `BoolIfExists` para exigir MFA.
- Decidir qué actions son "destructivas" sobre CloudTrail y Config.
- Argumentar por qué la SCP es `Deny` y no `Allow` (SCPs no otorgan).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §2 y §7.
- Haber recorrido `examples/01-scp-deny-regions/`.
- Herramientas: `bash`, `jq`, un editor. Nada de AWS CLI, nada de credenciales.

**Costos**: cero.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-06-scp-baseline/policies
cd /tmp/aws-06-scp-baseline
```

Puedes usar otro directorio, pero pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe tres SCPs

Cada una en `policies/`:

- **`policies/01-deny-regions.json`** — `Deny` de todo salvo servicios globales, cuando `aws:RequestedRegion` no esté en `["us-east-1", "eu-west-1"]`. **Pista:** usa `NotAction` para excluir IAM, STS, Route53, CloudFront, soporte, WAF.
- **`policies/02-deny-audit-tamper.json`** — `Deny` de las operaciones destructivas sobre CloudTrail y Config. Incluye al menos: `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`, `cloudtrail:UpdateTrail`, `config:DeleteConfigurationRecorder`, `config:StopConfigurationRecorder`, `config:DeleteDeliveryChannel`.
- **`policies/03-require-mfa-destructive.json`** — `Deny` de operaciones destructivas sobre S3 y IAM users **cuando NO haya MFA** en la sesión. Incluye al menos: `s3:DeleteBucket`, `s3:DeleteObject`, `iam:DeleteUser`, `iam:DeleteAccessKey`. Usa `BoolIfExists` sobre `aws:MultiFactorAuthPresent` (si usas `Bool` plano y la clave no aparece, el `Deny` no se dispara en principals federados — eso es un hueco).

Cada archivo debe ser JSON válido, con `Version` `"2012-10-17"`, `Statement` array con al menos un `Statement`, y los `Statement` con `Effect`, `Action` (o `NotAction`), `Resource` (o `NotResource`).

### 5.3 Escribe `BASELINE.md`

Con cuatro secciones:

#### Sección A — Resumen

Qué OU protege, qué principio aplica (deny-by-default + guardrails), por qué SCPs y no identity policies.

#### Sección B — Una subsección por SCP

Para cada una:

- Nombre del archivo.
- Qué deniega.
- Qué **no** deniega y por qué (ej: deny-regions no niega IAM porque es global).
- Qué ataque concreto previene (una línea).

#### Sección C — Interacción con identity policies

Responde:

- Si una identity policy permite `cloudtrail:DeleteTrail`, ¿qué pasa cuando esta SCP está activa? ¿Por qué?
- ¿Podría un admin de cuenta burlar la SCP editando su propia identity policy? ¿Por qué no?

#### Sección D — Tres piezas más que añadirías mañana

Lista corta: tres SCPs que *no* escribiste hoy pero añadirías a este baseline (ej: deny `organizations:LeaveOrganization`, deny root user, require tags en RunInstances). Para cada una, una línea de justificación.

### 5.4 Entregable

```
/tmp/aws-06-scp-baseline/
├── BASELINE.md
└── policies/
    ├── 01-deny-regions.json
    ├── 02-deny-audit-tamper.json
    └── 03-require-mfa-destructive.json
```

## 6. Resultado esperado

- Los tres JSON son válidos estructuralmente (el validador lo verifica con `jq`).
- Cada JSON tiene al menos un `Statement` con `Effect: Deny`.
- `01-deny-regions.json` menciona `aws:RequestedRegion` y usa `NotAction`.
- `02-deny-audit-tamper.json` menciona al menos `cloudtrail:` y `config:`.
- `03-require-mfa-destructive.json` menciona `aws:MultiFactorAuthPresent` **y** usa `BoolIfExists` (o `Bool` con justificación en el MD de por qué estás eligiendo esa variante).
- `BASELINE.md` tiene las cuatro secciones y responde las dos preguntas de §C.
- `bash tests/validate.sh /tmp/aws-06-scp-baseline` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: `BASELINE.md` nombra el ataque concreto que cada SCP previene (no vale "mejora la seguridad").
- **Reproducibilidad**: alguien que tome tus JSON y los adjunte a una OU en una cuenta sandbox obtendría el comportamiento esperado.
- **Mantenibilidad**: JSON formateado, nombres de SCP coherentes con convención (`DenyX`, `RequireY`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-06-scp-baseline
```

El validador comprueba **estructura** (no semántica). La corrección conceptual la revisas contra `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué `BoolIfExists` sobre `aws:MultiFactorAuthPresent` es más robusto que `Bool`? ¿En qué escenario fallaría `Bool`?
2. ¿Puede una SCP otorgar permisos? ¿Por qué el formato permite `Allow` entonces?
3. Si quisieras permitir `cloudtrail:StopLogging` solo al equipo de seguridad (digamos, al rol `arn:aws:iam::*:role/SecOps`), ¿pondrías esa excepción en la SCP o en la identity policy del rol? ¿Por qué?
4. ¿Qué pasa si otra SCP en una OU padre ya deniega las mismas acciones? ¿Hay conflicto, redundancia o complementariedad?
5. Si una cuenta pasa de la OU `sandbox` a la OU `prod`, ¿qué puede romperse de la noche a la mañana por culpa de este baseline?

## 10. Extensiones

- Añade una cuarta SCP: `04-deny-leave-org.json` que niegue `organizations:LeaveOrganization`.
- Añade una condition `aws:PrincipalArn` que exceptúe un rol concreto de SecOps en la SCP de audit-tamper.
- Diseña la variante del baseline para la OU `sandbox` (menos estricta: solo deny-regions, sin audit, sin MFA).

## 11. Limpieza

```bash
rm -rf /tmp/aws-06-scp-baseline
```

No hay AWS, no hay procesos, no hay nada que detener fuera del scratch.

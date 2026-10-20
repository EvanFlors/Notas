# Actividad 02 — ADR: MFA en root y admin no-root (OBLIGATORIA antes de cualquier otro módulo)

## 1. Identificación

- **ID:** `aws-01-02-root-mfa-and-admin-user`
- **Tecnología:** `aws`
- **Módulo:** `aws-01-model-regions-billing-and-free-tier`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent (sin dependencia de la actividad 01)
- **Estado:** **obligatoria** antes de empezar `aws-02`. Si no la haces, los módulos siguientes asumen un estado de cuenta que no tienes.

## 2. Contexto

En el §9 de la lección aprendiste el runbook de día 1 de una cuenta AWS. Dos pasos son no-negociables: **MFA en root** y **crear un admin humano no-root**. Esta actividad no te pide ejecutarlos en una cuenta real (no estás obligado a tener una); te pide **documentar la decisión** con la profundidad que un auditor querría leer.

El entregable es un **Architecture Decision Record (ADR)** más un **checklist** firmado (con tu nombre y fecha) que simula la ejecución del runbook.

## 3. Objetivos

Al terminar deberías tener:

- Un `ADR-001-root-blindado.md` con las secciones estándar de ADR (Context, Decision, Status, Consequences, Alternatives).
- Un `CHECKLIST.md` con las acciones ejecutadas, firmado (nombre + fecha).
- Una sección en el ADR que **compare** IAM user vs IAM Identity Center y defienda tu decisión.
- Una sección "Blast radius" que describa qué pasa si el root se compromete **sin** MFA.
- Enumeración de **≥3 vectores de ataque** que MFA en root mitiga.

## 4. Prerrequisitos

- Lectura de `../../theory/lesson.md`, especialmente §1, §4, §5, §6, §9.
- Herramientas: `bash`, editor Markdown. No necesitas cuenta de AWS.

**Costos:** cero.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-01-root-mfa
cd /tmp/aws-01-root-mfa
```

Si usas otro directorio: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-001-root-blindado.md`

Estructura mínima (si falta una sección, el validador falla):

```
# ADR 001 — Blindaje del root y creacion del admin no-root

## Status
Accepted — <fecha>

## Context
Describe el estado inicial: cuenta nueva (AccountId placeholder 123456789012),
sin MFA en root, sin admin humano, sin budget. Que riesgos existen hoy.

## Decision
Decision tomada:
1. MFA en root (TOTP + guardado offline).
2. Admin humano no-root via <IAM user con MFA | IAM Identity Center>.
3. Cero access keys estaticas en root.
4. Budget con alerta antes de cualquier recurso de pago.
Explica por que esta decision y no otra.

## Alternatives considered
- Alternativa A: no activar MFA (que riesgos).
- Alternativa B: usar access keys de root para automatizar (por que es un anti-patron).
- Alternativa C: IAM user con access keys estaticas vs IAM Identity Center (compara).

## Consequences
- Positivas: ...
- Negativas / costes: ...
- Que pasos siguientes habilita esto (puente a aws-02).

## Vectores de ataque mitigados
Lista al menos 3 vectores concretos que MFA en root mitiga.
Ejemplos: credential stuffing contra email root, phishing del password root,
leak de la password en un dump publico.

## Blast radius: root comprometido sin MFA
Describe en 5-10 bullets que puede hacer un atacante con credenciales root sin MFA.
Incluye: billing, borrar CloudTrail, borrar la cuenta, crear access keys,
cambiar email root, cambiar MFA...
```

### 5.3 Escribe `CHECKLIST.md`

Estructura obligatoria:

```
# Checklist de blindaje de root

Ejecutado por: <TU NOMBRE>
Fecha: <YYYY-MM-DD>
Cuenta objetivo: 123456789012

- [x] MFA activado en root (TOTP, seed guardado offline)
- [x] Access keys de root inexistentes / borradas
- [x] IAM access to Billing habilitado
- [x] Budget 20 USD/mes creado con alerta email
- [x] Admin humano no-root creado con MFA (IAM Identity Center / IAM user)
- [x] Sesion de root cerrada
- [x] CloudTrail multi-region activo

## Evidencia (simulada)
Pega el output esperado de `aws sts get-caller-identity --profile admin`:

` ` `json
{
    "UserId": "...",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_xxxx/<tu-usuario>"
}
` ` `
```

Nota: las casillas marcadas (`- [x]`) **simulan** la ejecución, no se exige acceso real a AWS. Si tienes acceso real, mejor: ejecútalo de verdad.

### 5.4 Entregables

```
/tmp/aws-01-root-mfa/
├── ADR-001-root-blindado.md
└── CHECKLIST.md
```

## 6. Resultado esperado

- Ambos archivos existen.
- ADR tiene las 6 secciones obligatorias.
- Al menos 3 vectores de ataque enumerados.
- Blast radius con al menos 5 bullets.
- Checklist firmado con nombre y fecha (regex `^Ejecutado por:` y `^Fecha:`).
- `bash tests/validate.sh /tmp/aws-01-root-mfa` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: la decisión IAM user vs Identity Center está defendida con al menos 2 criterios distintos (p. ej. rotación de credenciales, escalabilidad multi-cuenta).
- **Reproducibilidad**: alguien más puede repetir tu runbook mental.
- **Seguridad**: `AccountId` usado es `123456789012`, no uno real. No pegas secretos.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-01-root-mfa
```

Comprueba **estructura**, no semántica. Compara con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué MFA por TOTP (app) es menos resistente que MFA por hardware token (U2F/FIDO2) para root?
2. Si una organización no puede permitirse Identity Center (p. ej. cuenta solo-dev personal), ¿qué compromiso aceptable queda?
3. ¿Cómo auditarías periódicamente que **nadie** ha vuelto a crear access keys en root?
4. ¿Qué pasa con el root el día que la persona que abrió la cuenta deja la empresa?
5. ¿Por qué una SCP de Organizations **no** puede impedir que root haga algo en su propia cuenta?

## 10. Extensiones

- Añade una sección "Rotación de MFA" al ADR: qué pasa si pierdes el token.
- Añade un segundo ADR (`ADR-002-sso-adoption.md`) proponiendo adoptar Identity Center si decidiste IAM user en ADR-001.
- Dibuja un diagrama ASCII del flujo "humano → SSO portal → STS → credenciales temporales" para contrastar con "humano → access keys estáticas".

## 11. Limpieza

```bash
rm -rf /tmp/aws-01-root-mfa
```

Nada en AWS.

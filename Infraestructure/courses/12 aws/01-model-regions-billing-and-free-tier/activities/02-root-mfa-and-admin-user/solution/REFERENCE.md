# REFERENCE — aws-01-02-root-mfa-and-admin-user

> Lee **después** de haber escrito tu ADR y checklist.

## `ADR-001-root-blindado.md` (referencia)

```markdown
# ADR 001 — Blindaje del root y creacion del admin no-root

## Status
Accepted — 2026-10-16

## Context
Cuenta AWS nueva (AccountId placeholder 123456789012) abierta para un proyecto piloto. Estado:
- Root creado con email del equipo, password en gestor compartido.
- No hay MFA en root.
- No hay otros IAM users ni roles humanos.
- No hay IAM Identity Center habilitado en la organizacion.
- No hay budget, no hay CloudTrail.

Riesgo material: cualquier persona con el password del root puede, sin friccion adicional, (a) crear access keys permanentes, (b) borrar auditoria, (c) escalar gasto a limites de credito, (d) cambiar email root y bloquear a los legitimos duenos. El root es, por disenio, no-restringible via SCP.

## Decision
1. **MFA en root** con TOTP de app autenticadora, con el seed grabado offline (QR impreso en sobre, guardado en caja fuerte fisica o en bitwarden/1Password con MFA propia).
2. **Admin humano no-root via IAM Identity Center** (preferido sobre IAM user). Permission set `AdministratorAccess` asignado al usuario del directorio.
3. **Cero access keys estaticas en root.** Si existen de un setup previo, se borran como paso 2 del runbook.
4. **Budget 20 USD/mes con alertas** (50/80 % actual, 100 % forecast) **antes** de provisionar nada.
5. **CloudTrail** multi-region activo desde el dia 1.

## Alternatives considered
- **Alternativa A — No activar MFA en root.** Rechazada: deja la cuenta a merced de cualquier leak del password. Zero friccion para un atacante.
- **Alternativa B — Usar access keys de root para scripts/automatizacion.** Rechazada: viola todas las guias de AWS Well-Architected. Credenciales permanentes con permisos ilimitados y no-restringibles. Equivale a dejar la llave maestra en un `.env`.
- **Alternativa C — IAM user con access keys estaticas vs Identity Center.** Identity Center gana porque:
  - Credenciales **temporales** por default (STS, 1-12 h), rotadas automaticamente.
  - MFA integrado y aplicable a nivel de directorio.
  - Un portal unico para N cuentas (importante aun si hoy solo hay 1 cuenta, porque creceran).
  - Sin access keys que puedan fugar via `.env`, git o historial de shell.
  El IAM user queda como fallback aceptable **solo** en cuentas personales de laboratorio donde Identity Center sea desproporcionado.

## Consequences
- **Positivas**:
  - Blast radius de un leak de password reducido drasticamente (atacante aun necesita el segundo factor).
  - CloudTrail da trazabilidad; podemos auditar que nadie reactivo access keys de root.
  - Budget evita la primera factura sorpresa.
  - Habilita los proximos modulos del curso (aws-02 asume este estado).
- **Negativas / costes**:
  - Operativa adicional: hay que custodiar el MFA del root (caja fuerte, procedimiento de rotacion, procedimiento de "que pasa si la persona que lo guarda se va").
  - Identity Center tiene curva de aprendizaje; para una cuenta personal puede sentirse pesado.
  - CloudTrail genera volumen en S3 (barato pero no-free a largo plazo).

## Vectores de ataque mitigados
1. **Credential stuffing** contra el email root reutilizando passwords filtrados en otros servicios.
2. **Phishing** del password root por email simulando "AWS Security Alert".
3. **Leak del password manager** compartido donde esta guardado el password root.
4. (Bonus) **Session hijacking** si alguien se olvida la sesion abierta en un equipo compartido — MFA no mitiga totalmente esto una vez logeado, pero la sesion expira.

## Blast radius: root comprometido sin MFA
Si un atacante obtiene el password del root y **no** hay MFA:
- Crea **access keys para root** → persistencia infinita, invisible para cualquier guardrail.
- **Deshabilita CloudTrail** o borra los logs ya emitidos (si el bucket es de la misma cuenta).
- **Crea un IAM user con AdministratorAccess** y access keys, se las lleva — persistencia aun si cambias el password root luego.
- **Cambia el email del root** y bloquea a los legitimos duenos de la cuenta (muy dificil de recuperar; requiere soporte AWS con documentacion legal).
- **Lanza workloads caros** (minar crypto en GPU instances de regiones remotas donde no mires) → factura de miles de USD en horas.
- **Comparte recursos cross-account** (buckets, AMIs, snapshots) con cuentas controladas por el atacante → exfiltracion.
- **Cambia Payment Methods** para intentar escalar gasto antes de ser detectado.
- **Cierra la cuenta** (ultima vuelta de tuerca, posible con solo acceso root).
- **Modifica la MFA** y bloquea tus intentos de recuperacion.
- **Lee todos los secretos** en Secrets Manager y SSM Parameter Store.

Un **MFA de hardware** (U2F/FIDO2) mitiga incluso phishing en real-time porque el token esta vinculado al dominio origen.
```

## `CHECKLIST.md` (referencia)

```markdown
# Checklist de blindaje de root

Ejecutado por: Alice Example (CISO interim)
Fecha: 2026-10-16
Cuenta objetivo: 123456789012

- [x] MFA activado en root (TOTP, seed guardado offline en caja fuerte)
- [x] Access keys de root inexistentes (nunca se crearon)
- [x] IAM access to Billing habilitado
- [x] Budget 20 USD/mes creado con alertas 50%/80% actual + 100% forecast, email finops@example.com
- [x] IAM Identity Center habilitado; permission set AdministratorAccess asignado a alice@example.com
- [x] Sesion de root cerrada; password + seed MFA custodiados en gestor con MFA propia
- [x] CloudTrail multi-region activo (trail "org-trail"), logs validados hacia bucket cloudtrail-123456789012-logs

## Evidencia (simulada)

Ejecutado tras configurar perfil SSO 'admin':

` ` `json
{
    "UserId": "AROAEXAMPLE:alice",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_abcd1234/alice"
}
` ` `

A partir de aqui, cualquier operacion en la cuenta se hace con este rol asumido. Root queda inactivo hasta la proxima tarea que lo requiera explicitamente (cambio de plan de soporte, cierre de cuenta, cambio de email root).
```

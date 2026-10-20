# Actividad 02 — Respuesta a incidente: secreto filtrado en main

## 1. Identificación

- **ID:** `sec-04-02-incident-response-exercise`
- **Tecnología:** `devsecops`
- **Módulo:** `04-secret-scanning-gitleaks-trufflehog-github`
- **Dificultad:** intermediate
- **Duración estimada:** 40–60 min
- **Tipo:** independent (sin dependencia con la actividad 01)

## 2. Contexto — escenario a resolver

Lunes 10:30. El job `secret-scan` de GitHub Actions ha fallado en `main` con el siguiente hallazgo:

```
File: services/billing/config.yaml
Commit: a1b2c3d4 (hace 11 días, viernes 02/10)
Author: alice@example.com
Line 14: STRIPE_SECRET_KEY: sk_fake_live_FAKEstripe00000000000000demo
Rule: stripe-access-key
```

(El valor es evidentemente ficticio para este ejercicio. En la realidad sería una clave viva.)

Datos de contexto:
- El repo es **privado**, pero tiene 3 forks internos y ~40 clones locales dispersos en 2 equipos.
- GitHub secret scanning no estaba activado (sin GHAS). El hallazgo lo cazó gitleaks en CI al mergearse una PR nueva que modificaba el mismo archivo.
- El servicio `billing` está en producción y usa esa clave para capturar pagos.
- La ventana de exposición: viernes 02/10 10:00 → lunes 13/10 10:30 (~11 días; el commit vivió todo el fin de semana).
- Hay logs de Stripe retenidos 90 días.

**Tu tarea**: redactar `RESPONSE.md` describiendo exactamente qué harías, en qué orden, en los próximos 60 minutos y en las 48h siguientes.

## 3. Objetivos

- Ordenar correctamente la respuesta: **rotar → notificar → investigar → reescribir historia → coordinar re-clone → post-mortem**.
- Justificar por qué invertir cualquiera de esos pasos empeora la situación.
- Identificar al menos 3 **anti-patrones** y refutarlos.
- Proponer 2–3 controles preventivos (push protection, pre-commit obligatorio, etc.) que habrían evitado o detectado antes el leak.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` del módulo (en particular §5 y §7).
- Haber recorrido `examples/03-rotate-then-rewrite-history/`.
- Herramientas: `bash` y un editor Markdown. **Nada se ejecuta** en esta actividad; es análisis puro.

**Nota de seguridad**: aunque la clave del escenario es evidentemente falsa, **no** la copies a un repo real ni la uses para probar `git filter-repo`. Todo el ejercicio es redacción.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-04-incident
cd /tmp/sec-04-incident
```

### 5.2 Escribir `RESPONSE.md` con las secciones requeridas

#### Sección A — Cronología (próximos 60 min)

Lista numerada con cada paso, formato: `N. [HH:MM] Acción → por qué ahora y no antes/después`.

Debe incluir, en este orden:

1. Confirmar hallazgo (no FP).
2. **Rotar** la clave en Stripe (emitir nueva, revocar vieja).
3. Desplegar servicio con la nueva clave.
4. Notificar a seguridad / lead del servicio.

#### Sección B — Investigación (siguientes 2–6 h)

- Qué logs revisar en Stripe (fechas exactas de la ventana de exposición).
- Qué señales serían "evidencia de abuso".
- Umbral que escalaría a incidente mayor.

#### Sección C — Limpieza (24–48 h)

- Comando o guión con `git filter-repo --replace-text` (o BFG) sobre un clone fresh.
- Plan de force-push + comunicación al equipo para re-clone.
- Qué hacer con los 3 forks internos.

#### Sección D — Anti-patrones

Al menos **3** anti-patrones, cada uno con 1–2 líneas refutándolo. Mínimo:

- `git rm services/billing/config.yaml && git commit`.
- `git commit --amend` sobre el último commit.
- Reescribir historia **antes** de rotar.

#### Sección E — Controles preventivos

Al menos **3** controles concretos que, de haber estado, habrían evitado o acortado el incidente. Candidatos: push protection, pre-commit obligatorio, trufflehog `--only-verified` en CI, política de rotación periódica, secrets manager (Vault/SOPS/ESO).

#### Sección F — Post-mortem (resumen)

Tres bullets:

- **Qué pasó** (una frase objetiva, sin culpables).
- **Causa raíz** (por qué el control que debía atraparlo no lo hizo).
- **Qué cambiamos** (link a la Sección E).

### 5.3 Entregable

Un archivo:

```
/tmp/sec-04-incident/RESPONSE.md
```

con las 6 secciones (A–F).

## 6. Resultado esperado

- `RESPONSE.md` existe y tiene las 6 secciones.
- La palabra `rotar` aparece **antes** que `filter-repo`/`bfg` en el documento.
- Menciona `blast radius`, `post-mortem`, `force-push`, y al menos un control preventivo concreto.
- `bash tests/validate.sh /tmp/sec-04-incident` pasa.

## 7. Criterios de aceptación

- **Orden operativo**: rotar precede siempre a reescribir historia.
- **Honestidad técnica**: no inventa controles mágicos; cada preventivo propuesto es implementable.
- **Mantenibilidad**: el documento sirve como plantilla reutilizable para futuros incidentes.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-04-incident
```

## 9. Preguntas de reflexión

1. Si Stripe no retuviera logs, ¿cambia tu Sección B? ¿Qué asumirías por defecto?
2. En vez de 11 días, el commit tiene **11 meses**. ¿Qué paso adicional aparece?
3. Un stakeholder pide "no hacer force-push para no molestar al equipo". ¿Cómo defiendes la reescritura?
4. ¿Por qué `git commit --amend` **no** sirve aquí aunque el commit sea del mismo autor?
5. Si el repo fuera **público**, ¿cambia el orden de la respuesta? ¿Qué pasos añades?

## 10. Limpieza

```bash
rm -rf /tmp/sec-04-incident
```

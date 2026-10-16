# Actividad 02 — ADR de rotación de secretos + procedimiento de break-glass

## 1. Identificación

- **ID:** `sec-13-02-rotation-and-break-glass-adr`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-13-secrets-at-scale-vault-eso-and-workload-identity`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** independent (sin dependencia de la actividad 01, sin infra)

## 2. Contexto

Te han puesto como *tech lead* de la nueva plataforma de pagos. Tu CTO necesita, antes de la próxima auditoría SOC2, dos documentos:

1. Una **política de rotación** por tipo de secreto, defendible frente a un auditor que preguntará: *"¿cada cuánto rotáis la password de la DB? ¿Y la API key de Stripe? ¿Y el cert TLS?"*.
2. Un **procedimiento de break-glass**: qué hace exactamente el on-call a las 3 am cuando Datadog expiró y necesita abrir el secret manager fuera del flujo normal, de forma que al día siguiente el audit log cuente la historia completa.

Ambos documentos van juntos en un ADR (Architecture Decision Record) clásico.

**No hay** cluster, ni Vault, ni código. Es análisis escrito.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Clasificar un secreto en una de tres familias: **dynamic (TTL)** / **estático con rotación automatizada** / **estático con rotación humana**, y justificarlo.
- Nombrar las 5 propiedades que cumple un procedimiento de break-glass sano.
- Diseñar un ADR que un revisor externo pueda **auditar** sin preguntarte nada en vivo.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §7, §8, §9, §10).
- Haber corrido mentalmente los tres `examples/` (no hace falta ejecutar).
- Opcional: haber hecho el curso `sec-02` (overview de secretos).

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Prepara el directorio de trabajo

```bash
mkdir -p /tmp/sec-13-rotation-adr
cd /tmp/sec-13-rotation-adr
cp <ruta-repo>/courses/devsecops/13-secrets-at-scale-vault-eso-and-workload-identity/activities/02-rotation-and-break-glass-adr/starter/TEMPLATE.md ADR.md
```

Puedes usar otro directorio; pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Rellena `ADR.md`

El documento tiene cuatro secciones obligatorias en formato ADR clásico:

#### Status

`Proposed` / `Accepted` / `Deprecated`. Para esta actividad, `Accepted`.

#### Context

Describe en 1–2 párrafos:

- Qué organización ficticia estás modelando (tamaño, cloud, nº de servicios, nº de clusters).
- Qué está rompiendo hoy (ej.: "secrets vivos 2 años", "no hay audit log", "rotación manual olvidada").
- Qué constraints no negociables tienes (ej.: SOC2 en 90 días, presupuesto X, equipo de Y personas).

#### Decision

Dos subsecciones:

##### A. Tabla de rotación (al menos 5 tipos de secretos)

Rellena esta tabla con **al menos 5 filas**. Para cada secreto, decide:

| Secreto | Familia | Trigger | TTL / Frecuencia | Mecanismo | Zero-downtime | Blast radius de fuga |
|---------|---------|---------|------------------|-----------|---------------|----------------------|
| DB password (Postgres propio) | dynamic | TTL vencido | 60 min | Vault `database/` + pool rotation | sí | ≤ 60 min |
| API key Stripe | estático / humano+automatizado | cron 90d | 90 días | ... | ... | ... |
| Cert TLS wildcard | ... | ... | ... | ... | ... | ... |
| OAuth client secret | ... | ... | ... | ... | ... | ... |
| SSH host key del bastion | ... | ... | ... | ... | ... | ... |

**Familias permitidas** (nómbralas tal cual):

- `dynamic` — Vault lo emite al vuelo con TTL.
- `estatico-rotado-automatizado` — cron/script rota contra API externa y actualiza Vault/kv.
- `estatico-rotado-humano` — intervención manual con calendario.

La "Justificación" de la familia debe estar implícita en la columna *Mecanismo* (si no, añade una línea de prosa debajo de la tabla).

##### B. Procedimiento de break-glass

Describe un procedimiento numerado (1., 2., 3., ...) con al menos **5 pasos**, que demuestre las **5 propiedades** siguientes (menciónalas explícitamente en el texto):

1. **Autenticación fuerte** (2FA, hardware key, o SSO con MFA).
2. **Rastro inmutable** (audit log, sink append-only).
3. **Scope mínimo** (policy específica, no `root`).
4. **TTL del token break-glass** (minutos, no horas).
5. **Review post-mortem obligatorio** con plazo (< 24 h).

#### Consequences

En 1–2 párrafos: qué ganas, qué pierdes, qué asumes. En particular:

- Costo operativo del nuevo modelo (ej.: equipo tiene que aprender Vault; pipelines CI tocarán ESO).
- Riesgo residual (ej.: si Vault se cae, blast radius; cómo mitigar).
- Qué requiere seguir refinando en 6 meses.

### 5.3 Entregable

Un archivo:

```
/tmp/sec-13-rotation-adr/ADR.md
```

con las cuatro secciones (`Status`, `Context`, `Decision` con A y B, `Consequences`).

## 6. Resultado esperado

- `ADR.md` existe y es coherente.
- La tabla A tiene **al menos 5 filas** con las 7 columnas rellenas.
- Al menos 3 **familias** distintas aparecen en la columna "Familia" (demuestra que entiendes que no todo puede ser dinámico).
- El procedimiento B tiene al menos **5 pasos numerados** y menciona las 5 propiedades.
- `bash tests/validate.sh /tmp/sec-13-rotation-adr` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad:** validador estructural pasa.
- **Calidad:** cada familia está defendida por el *mecanismo*, no por "porque sí".
- **Reproducibilidad:** un revisor que lea tu ADR puede, en 5 min, decir si lo aprueba o pide cambios.
- **Mantenibilidad:** Markdown válido, tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-13-rotation-adr
```

Comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué el SSH host key del bastion **no** puede ser dinámico? ¿Hay una alternativa que haga el problema desaparecer?
2. Un auditor te pregunta: *"la API key de Stripe se rota cada 90 días, ¿cómo sé que de verdad se rotó?"*. ¿Qué le enseñas?
3. Tu procedimiento de break-glass requiere 2 personas (autenticación de 2). ¿Qué ocurre si una de las 2 está de vacaciones? ¿Qué prefieres: romper la propiedad "2 personas" o romper el SLO de respuesta?
4. Si tu CTO te dice *"con rotar 1 vez al año basta"*, ¿con qué argumento le muestras el coste real de esa decisión?
5. ¿Qué secreto de tu stack **personal** actual (laptop, GitHub, cloud) deberías rotar y no has rotado desde hace > 1 año?

## 10. Extensiones

- Añade una **sexta** fila a la tabla con un secreto de tu organización real (si aplica).
- Añade un diagrama ASCII del flujo de break-glass (qué sistemas tocan los pasos 1 → 5).
- Añade una sección `Alternatives considered` con 2 alternativas descartadas (ej.: "SOPS + git", "rotar todo cada semana") y por qué.

## 11. Limpieza

```bash
rm -rf /tmp/sec-13-rotation-adr
```

No hay procesos ni contenedores que detener.

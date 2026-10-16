# Actividad 01 — Inventario de secretos del proyecto

## 1. Identificación

- **ID:** `sec-02-01-audit-your-secrets`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-02-secrets-overview-and-principles`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

En un proyecto real, el **primer** trabajo antes de instalar Vault, OIDC o cualquier scanner **es ver dónde viven los secretos ahora**. Sin inventario no se puede priorizar, no se puede medir blast radius y no se puede decidir qué migrar primero.

Como no todas las personas que hacen este módulo tienen un capstone de referencia aún, trabajarás sobre el **modelo del capstone del curso**: una aplicación FastAPI dockerizada que se despliega vía GitHub Actions a GHCR, corre en Kubernetes y habla con PostgreSQL + Redis + Stripe + Datadog. Puedes **adaptar** el modelo al tuyo si ya tienes uno propio en marcha — mientras cumplas el esquema estructural.

El entregable es un documento Markdown escrito por ti. **No hay** cluster, ni `kubectl`, ni código. Es inventario + razonamiento.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Listar los secretos **plausibles** de un proyecto cloud-native típico.
- Clasificarlos por **familia** (de la §3 de la lección).
- Asignarles un **hogar** (1–7 del ejemplo 01).
- Dar un **blast radius** cualitativo (bajo / medio / alto / catastrófico) con justificación.
- Marcar cuáles tienen una **migración short-lived** evidente.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los dos `examples/` del módulo.
- Haber completado `sec-01`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. No se despliega nada.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/sec-02-audit
cd /tmp/sec-02-audit
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador:
`bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `INVENTORY.md` con cuatro secciones

#### Sección A — Contexto del proyecto auditado

Describe en 3–6 líneas qué sistema estás auditando (puede ser el modelo del capstone descrito arriba o uno propio). Debe quedar claro:

- Qué servicios lo componen.
- A qué sistemas externos habla (SaaS, DBs, colas).
- Cómo se despliega (CI/CD + runtime).

#### Sección B — Tabla de inventario

Produce una **tabla Markdown** con **al menos 5 filas** (secretos distintos). Columnas **obligatorias** (nombres sugeridos; mantén los que facilitan la validación):

```
| secret_id | familia | hogar | owner | TTL | rotation | blast_radius | short_lived? |
|-----------|---------|-------|-------|-----|----------|--------------|--------------|
```

Reglas por columna:

- `secret_id`: un identificador legible (`stripe_live_api_key`, `postgres_app_user`, …). **No** pongas valores reales. Si quieres mostrar formato, usa un marcador obviamente falso (`sk_fake_...`).
- `familia`: una de `api-key | db-cred | oauth | cert | ssh | signing | encryption`.
- `hogar`: `1` (Git) … `7` (HSM físico). Si está en varios, abre **una fila por hogar** con el mismo `secret_id` (haciendo visible la copia).
- `owner`: equipo o persona responsable (`platform`, `payments`, `data-eng`, `security`).
- `TTL`: tiempo real estimado hasta el próximo reemplazo (`730d`, `90d`, `15m`, `never`).
- `rotation`: `auto` | `manual` | `none`.
- `blast_radius`: `bajo` | `medio` | `alto` | `catastrofico`.
- `short_lived?`: `yes` | `no` | `candidate` (candidato a migrar a OIDC/WI/STS/dynamic).

#### Sección C — Top 3 riesgos del inventario

De las filas de la Sección B, elige los **3 secretos de mayor riesgo** y, por cada uno, escribe 2–4 líneas que respondan:

- Por qué su blast radius es el que marcaste.
- Qué acción de **mayor retorno** aplicarías (migrar a short-lived, estrechar scope, rotar + revocar, moverlo a secret manager).
- Qué principio de §5 de la lección estarías aplicando.

#### Sección D — Propuesta de migración

Describe en 5–10 líneas (bulletpoints OK) un **plan a 90 días** con 3–5 pasos ordenados. Cada paso debe:

- Elegir una fila concreta del inventario.
- Decir a qué hogar la mueves (p. ej. `#2 → #4`, `#4 → #6`).
- Justificar por qué ese paso **antes** que los otros.

### 5.3 Entregable

Un archivo:

```
/tmp/sec-02-audit/INVENTORY.md
```

con las cuatro secciones A, B, C, D.

## 6. Resultado esperado

- `INVENTORY.md` existe y es coherente.
- Sección B tiene **≥5 filas** con todas las columnas rellenas.
- Al menos una fila con `familia = api-key` y una con `familia = db-cred` (son los más comunes).
- Al menos **una fila** marcada `short_lived? = candidate` o `yes`.
- `bash tests/validate.sh /tmp/sec-02-audit` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada clasificación menciona la **familia** y el **hogar** del catálogo del módulo (no inventa).
- **Reproducibilidad**: alguien que lea tu documento puede reconstruir el stack auditado.
- **Mantenibilidad**: Markdown válido, tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-02-audit
```

El validador comprueba **estructura**, no semántica. Compara tu inventario con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. De tu top-3 de la Sección C, ¿cuál podrías eliminar entero (no sólo rotar) con OIDC/WI? ¿Por qué el equipo no lo ha hecho ya?
2. ¿Qué secreto, aunque tenga blast radius "bajo", es el **más caro** de migrar? ¿Vale la pena ese coste?
3. ¿Qué secreto de tu lista **no estabas tratando como secreto** y debería serlo (o viceversa)?
4. Si tuvieras que escribir una regla de scanning custom (`sec-04`) a partir de tu inventario, ¿qué patrón escogerías primero?
5. ¿Cuántas copias totales (filas) viste del mismo `secret_id`? ¿Qué dice eso del flujo de bootstrap del proyecto?

## 10. Extensiones

- Añade una columna `last_used` con lo que puedas inferir ("desconocido" vale como respuesta si tu secret manager no audita lecturas).
- Añade una columna `detectable_in_logs?` para marcar los secretos cuya fuga sería visible en logs (vs. silenciosa).
- Dibuja un diagrama ASCII simple del flujo "donde se usa cada secret_id" para los tres de la Sección C.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/sec-02-audit
```

No hay procesos ni contenedores que detener.

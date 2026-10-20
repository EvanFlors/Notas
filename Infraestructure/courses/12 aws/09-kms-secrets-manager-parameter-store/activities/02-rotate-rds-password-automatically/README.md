# Actividad 02 — Rotación automática de password de RDS (walkthrough + diseño)

## 1. Identificación

- **ID:** `aws-09-02-rotate-rds-password-automatically`
- **Tecnología:** `aws`
- **Módulo:** `aws-09-kms-secrets-manager-parameter-store`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

La rotación integrada **Secrets Manager ↔ RDS** se usa en producción permanentemente, pero no se puede reproducir honestamente contra LocalStack: necesita una Lambda real + un RDS real, red y permisos coordinados. Esta actividad es un **walkthrough + diseño**: documentas en un `ROTATION.md` cómo lo montarías, con suficiente nivel de detalle como para que otra persona pueda implementarlo.

**Todos los valores de ejemplo son fake y están etiquetados como tal.** Nunca pongas credenciales reales.

## 3. Objetivos

- Escribir `ROTATION.md` con las **6 secciones** requeridas (ver §5.2) y los artifacts estructurales que el validador comprueba.
- Defender tus decisiones: single-user vs multi-user, ventana de corte, ubicación de la Lambda rotator (VPC o no), y comportamiento ante fallo en `testSecret`.
- Clasificar **5 ítems** dados entre Secrets Manager y Parameter Store, con una justificación por ítem (criterio: rotación, tamaño, costo, visibilidad, compartido).

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` §7, y `examples/02-secrets-manager-rotation-walkthrough/README.md`.
- Herramientas: `bash` y un editor Markdown. Opcional: `jq`.

**Costos**: cero (todo es documental).

## 5. Instrucciones

### 5.1 Preparar scratch

```bash
mkdir -p /tmp/aws-09-rotate-rds
cd /tmp/aws-09-rotate-rds
```

### 5.2 Escribe `ROTATION.md` con 6 secciones

Las **secciones son obligatorias** y el validador las busca por heading:

1. **Sección A — Arquitectura**: diagrama ASCII con la Lambda rotator, Secrets Manager, RDS (postgres), la CMK y la VPC. Marca el flujo: `SM → Lambda (eventbridge invoke) → RDS (VPC) → SM (update stages)`. Mínimo 8 líneas y menciona `rotator`, `rds`, `secret`.
2. **Sección B — Ciclo de 4 pasos**: tabla o lista enumerada 1..4 con `createSecret`, `setSecret`, `testSecret`, `finishSecret`. Para cada paso: qué hace y qué pasa si falla. El validador requiere los 4 nombres literales presentes.
3. **Sección C — IAM**: snippet(s) JSON (en bloques de código) con:
   - Permisos del execution role de la Lambda (secretsmanager + kms + vpc).
   - Statement del rol en la **key policy** de la CMK.
   El validador exige al menos 1 bloque `json` y las acciones `kms:Decrypt` y `secretsmanager:GetSecretValue`.
4. **Sección D — Variantes single-user vs multi-user**: tabla comparando `single-user` y `multi-user (alternating)` con al menos 3 criterios (riesgo, ventana crítica, complejidad). Decisión explícita con palabra clave `single-user` o `multi-user` como elección razonada para el escenario de este diseño.
5. **Sección E — Fallos y runbook**: lista de 3+ escenarios de fallo (p. ej. `testSecret` falla por SG, VPC endpoint caído, `AWSPENDING` huérfano) con mitigación. Debe mencionar `AWSPENDING` y `AWSPREVIOUS`.
6. **Sección F — Decisiones Secrets Manager vs Parameter Store (5 ítems)**: tabla con exactamente 5 filas. Para cada ítem una categoría (`SecretsManager` | `ParameterStore` | `ParameterStore-SecureString`) y una justificación citando una de: `rotacion`, `tamano`, `costo`, `visibilidad`, `compartido`.

Items a clasificar:

| # | Ítem | Pista |
|---|------|-------|
| 1 | Password del master de PostgreSQL RDS | rotación con RDS |
| 2 | API token de un proveedor que no rota (ej. SaaS de analytics interno) | sensible pero no rotable |
| 3 | Endpoint del broker Kafka interno (`b-1.kafka.internal:9092`) | config no sensible |
| 4 | 300 feature flags booleanos del equipo frontend | volumen alto, no sensible |
| 5 | Private key (PEM) de firma de JWT, se rota cada 90 días | rotable, mantener `AWSPREVIOUS` |

Deja clara tu decisión. El validador cuenta filas y presencia de las palabras clave.

### 5.3 Entregable

```
/tmp/aws-09-rotate-rds/
└── ROTATION.md
```

## 6. Resultado esperado

- `bash tests/validate.sh /tmp/aws-09-rotate-rds` en verde.
- Diagrama presente, 4 pasos presentes, al menos un bloque JSON, 5 filas de clasificación.
- Valores *fake* etiquetados (`fake-`, `NOT-REAL`, `example`).

## 7. Criterios de aceptación

- **Estructura**: validador estructural en verde.
- **Correctness**: el modelo contra `solution/REFERENCE.md`.
- **Reproducibilidad**: alguien que lea `ROTATION.md` sabría dónde empezar en AWS real.

## 8. Validación

```bash
bash <ruta-repo>/courses/aws/09-kms-secrets-manager-parameter-store/activities/02-rotate-rds-password-automatically/tests/validate.sh /tmp/aws-09-rotate-rds
```

## 9. Preguntas de reflexión

1. ¿Por qué single-user puede dejar a la app fuera unos segundos y multi-user no?
2. ¿Qué pasa si la Lambda rotator corre fuera de la VPC donde está RDS? ¿Cómo lo resuelves?
3. ¿Por qué `AWSPREVIOUS` sigue existiendo tras `finishSecret`? ¿Durante cuánto tiempo deberías mantenerla?
4. ¿Qué criterio aplicarías si el "secreto" en realidad son 50 feature flags que cambian 10 veces al día?
5. ¿En qué caso tiene sentido guardar algo en Secrets Manager **sin** rotación automática?

## 10. Extensiones

- Añade una **Sección G** con el pseudo-código de `setSecret` para `multi-user`.
- Añade un diagrama de la secuencia de invocación por EventBridge Scheduler cada N días.
- Añade el runbook para rotación manual (`aws secretsmanager rotate-secret --rotate-immediately`).

## 11. Limpieza

```bash
rm -rf /tmp/aws-09-rotate-rds
```

No hay recursos remotos: todo es documental.

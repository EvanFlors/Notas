# Actividad 01 — Diseñar OU structure y escribir ADR

## 1. Identificación

- **ID:** `aws-15-01-design-ou-structure-and-adr`
- **Tecnología:** `aws`
- **Módulo:** `aws-15-multi-account-org-identity-center`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

Una startup de 20 personas (10 ingenieros, 3 data, 2 security, 5 negocio) va a entrar en AWS "en serio" después de un año en una sola cuenta. Dos workloads reales:

- **`checkout`**: API HTTP crítica, procesa pagos, SLA 99.9%, compliance PCI-light. Equipo backend de 4 personas.
- **`analytics`**: pipeline Spark + dashboards internos, no toca datos de pago, uso en horario laboral. 1 data engineer.

Más:

- **Finance** quiere ver billing agregado y por entorno.
- **Security** quiere logs centralizados y una cuenta donde correr GuardDuty.
- Todas las cargas deben vivir en **Europa** (compliance).
- Los developers deben poder experimentar sin arrancar nada caro accidentalmente.

Tu encargo: **diseñar la OU structure, el inventario de cuentas, las SCPs del baseline y el catálogo de Permission Sets**, y documentarlo en un ADR que un equipo de 5 personas pueda leer y ejecutar en Fase 4 con Terraform.

**Importante**: no hay cuenta AWS real. No se provisiona nada. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar una OU structure para una org pequeña y defender cada OU elegida.
- Decidir *"una app = una cuenta"* vs *"una app = N cuentas"* por workload y defender el criterio.
- Nombrar las SCPs del baseline, dónde las adjuntas y por qué.
- Mapear Permission Sets a grupos y a OUs (no a tuplas usuario-cuenta).
- Escribir un ADR legible por un ingeniero que no estuvo en la discusión.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §3 OU structure, §4 SCPs, §7–8 IdC/Permission Sets, §10 patrones de cuentas).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `aws-02` (IAM core) y `aws-06` (trust policies).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-15-ou-adr
cd /tmp/aws-15-ou-adr
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-ORG-STRUCTURE.md`

Un **ADR** (Architecture Decision Record) es un documento corto y versionado. Formato que debes seguir:

```
# ADR 001 — Estructura de la organización AWS

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: qué problema resuelves, qué constraints hay)

## Decisión
(La estructura que eliges, concreta: OUs, cuentas, patrón por workload,
SCPs atadas, Permission Sets. Idealmente con un diagrama ASCII.)

## Consecuencias
(Qué ganas, qué pierdes, qué se vuelve más fácil, qué más caro.
Debe cubrir tanto positivas como negativas.)

## Alternativas descartadas
(Al menos 2 alternativas consideradas y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- **Diagrama ASCII** de la OU structure propuesta (con fences de código).
- **Al menos 4 cuentas** nombradas (p. ej. `management`, `log-archive`, `audit`, `checkout-prod`...).
- **Al menos 3 SCPs** del baseline nombradas (`deny-regions`, `deny-leave-organization`, `deny-disable-logging` u otras).
- **Al menos 3 Permission Sets** del catálogo (`AdministratorAccess`, `ReadOnlyAccess`, `PowerUserAccess`, `BillingReadOnly`, `BreakGlassProd`...).
- Mención explícita de **IAM Identity Center** y de **AWS Organizations**.
- Una decisión explícita sobre **"una app = una cuenta" vs "una app = N cuentas"** para `checkout` y para `analytics`.
- Mención de **Europa** / `eu-west` / `eu-central` (compliance de región).

### 5.3 Entregable

Un archivo:

```
/tmp/aws-15-ou-adr/ADR-ORG-STRUCTURE.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-ORG-STRUCTURE.md` existe y es coherente.
- El validador pasa en verde.
- Un ingeniero externo puede leerlo y entender **qué** vas a montar y **por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no solo listada).
- **Reproducibilidad**: alguien en Fase 4 podría tomar este ADR y convertirlo a Terraform sin ambigüedades mayores.
- **Mantenibilidad**: Markdown válido, diagramas en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-15-ou-adr
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué `checkout` conviene en 3 cuentas (dev/stg/prod) y `analytics` quizás en 1 sola? ¿Qué criterio aplicaste?
2. Si en 2 años aparecen 10 workloads más, ¿tu estructura escala o la tendrías que rehacer?
3. ¿Dónde pondrías el pipeline de CI/CD (cuenta de *tools*)? ¿Por qué no en el management?
4. ¿Qué pasa el día que `Finance` pide ver *solo* el gasto de `checkout-prod`? ¿Tu estructura lo hace fácil?
5. Si un auditor pregunta "muéstrame todo lo que puede hacer el grupo `developers` en `checkout-prod`", ¿cómo le respondes?

## 10. Extensiones

- Añade una sección **"Fase 2"** al ADR describiendo cambios previsibles cuando la org crezca a 10+ workloads.
- Dibuja un **diagrama de assignments** (grupos × permission sets × OUs) como tabla.
- Añade una SCP custom (fuera del baseline) justificada por el contexto PCI-light de `checkout`.

## 11. Limpieza

```bash
rm -rf /tmp/aws-15-ou-adr
```

No hay procesos ni infraestructura que detener.

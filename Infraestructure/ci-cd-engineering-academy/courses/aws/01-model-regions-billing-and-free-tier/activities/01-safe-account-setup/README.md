# Actividad 01 — Runbook de puesta en marcha segura de una cuenta AWS nueva

## 1. Identificación

- **ID:** `aws-01-01-safe-account-setup`
- **Tecnología:** `aws`
- **Módulo:** `aws-01-model-regions-billing-and-free-tier`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Tu equipo acaba de abrir una cuenta AWS nueva para un proyecto piloto. Nadie ha tocado nada aún. Tú eres responsable de dejar la cuenta en **estado seguro antes de provisionar un solo recurso**. No tienes acceso a hacer cambios en vivo (y aunque lo tuvieras, este curso no te deja porque aún no has visto IAM): tu entregable es el **runbook escrito** que seguiría quien sí tenga acceso.

El runbook debe ser **operable**: comandos reales, orden exacto, qué comprobar después de cada paso, qué hacer si falla.

## 3. Objetivos

Al terminar deberías tener:

- Un `ACCOUNT-SETUP.md` con los **7 pasos del día 1** del §9 de la lección en orden, cada uno con **(a)** descripción del paso, **(b)** comando(s) CLI o navegación de consola, **(c)** verificación.
- Un bloque de **budget** basado en el ejemplo 02, con decisión documentada del umbral y del canal de alerta.
- Una lista de **≥5 cargos silenciosos** (fuera de Free Tier) con monto aproximado por mes.
- Un `COSTS.md` separado con una **estimación manual** de un workload trivial (una EC2 `t3.micro` + un bucket S3 de 10 GB + 50 GB egress mensual) hecha con Pricing Calculator o cálculo propio.

## 4. Prerrequisitos

- Lectura completa de `../../theory/lesson.md`.
- Haber recorrido `../../examples/01-cli-profiles-and-sts/` y `../../examples/02-budget-with-sns-alert/`.
- Herramientas: `bash`, editor Markdown. **No** necesitas cuenta de AWS para esta actividad.

**Costos:** cero.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-01-setup
cd /tmp/aws-01-setup
```

Si usas otro directorio, pasa la ruta al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ACCOUNT-SETUP.md`

Estructura obligatoria (si una sección no está, el validador falla):

```
# Runbook: puesta en marcha segura de cuenta AWS

## Paso 1 — MFA en root
Descripción, comando/navegación, verificación.

## Paso 2 — Borrar access keys de root
Descripción, comando/navegación, verificación.

## Paso 3 — IAM access to Billing
Descripción, comando/navegación, verificación.

## Paso 4 — Budget con alerta
Descripción, comandos (CLI o terraform plan), verificación.

## Paso 5 — Admin humano no-root
Descripción, decisión IAM user vs Identity Center, comandos, verificación.

## Paso 6 — Cerrar sesión de root
Descripción + checklist.

## Paso 7 — CloudTrail
Descripción, comando, verificación.

## Cargos silenciosos (fuera de Free Tier)
Lista de al menos 5 (con monto aproximado USD/mes).
```

Para cada paso incluye **al menos un comando** real. Ejemplos de comandos aceptables:

- `aws sts get-caller-identity --profile X`
- `aws iam list-access-keys --user-name root` *(nota: en realidad root no se lista así; documenta la limitación)*
- `aws budgets create-budget ...`
- `aws cloudtrail create-trail --name ...`

El validador cuenta cuántos bloques de código `bash` aparecen y exige **≥7**.

### 5.3 Escribe `COSTS.md`

Estructura:

```
# Estimacion mensual — workload trivial

## Workload
- 1 x EC2 t3.micro, 730 h/mes, us-east-1, Linux on-demand
- 10 GB S3 Standard
- 50 GB egress a internet
- Opcional: 1 NAT Gateway (describe el impacto si se usa)

## Estimacion
| Item | Precio unitario | Cantidad | Mensual |
|------|-----------------|----------|---------|
| ... | ... | ... | ... |
| Total |  |  | X USD |

## Comentarios
Explica (a) que entra en Free Tier (12 meses) y que no, (b) por que el NAT Gateway solo cambia radicalmente la cifra.
```

Los números no tienen que ser exactos a 2 decimales; sí deben ser del **orden de magnitud correcto** (una `t3.micro` on-demand en `us-east-1` ronda ~7–8 USD/mes; S3 Standard ~0.023 USD/GB; egress 50 GB sobre free tier es trivial; NAT ~32 USD/mes solo por existir + egress procesado).

### 5.4 Entregables

```
/tmp/aws-01-setup/
├── ACCOUNT-SETUP.md
└── COSTS.md
```

## 6. Resultado esperado

- Ambos archivos existen y pasan validación estructural.
- `ACCOUNT-SETUP.md` cubre los 7 pasos en orden.
- Al menos 7 bloques de código `bash` (comandos reales).
- Al menos 5 cargos silenciosos listados.
- `COSTS.md` tiene tabla con totales.
- `bash tests/validate.sh /tmp/aws-01-setup` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada paso tiene verificación posterior (`sts get-caller-identity`, consola, output esperado).
- **Reproducibilidad**: otra persona del equipo podría ejecutar el runbook paso a paso.
- **Seguridad**: no incluyes credenciales reales, usas `123456789012` como placeholder.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-01-setup
```

Comprueba estructura, **no** semántica. Compara con `solution/TEMPLATE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué el paso 4 (budget) está **antes** del paso 5 (admin user)? ¿Qué pasaría si lo pusieras después?
2. Si el equipo decide usar IAM Identity Center en vez de IAM user, ¿qué cambia en el paso 5 y qué pasos se ahorran?
3. ¿Qué cargo silencioso del listado te sorprendió más al estimar su costo mensual?
4. ¿Por qué el runbook recomienda MFA en hardware token y no solo TOTP para root?
5. ¿Cómo validarías, **sin** acceso a facturación, que una cuenta sigue el runbook correctamente?

## 10. Extensiones

- Añade un paso 0 "Antes de abrir la cuenta" (elegir email, elegir plan de soporte).
- Añade una sección "Modo multi-cuenta" explicando qué cambia si esto fuera una cuenta más dentro de un AWS Organization.
- Escribe un pequeño script `verify-setup.sh` (no se evalúa; pensamiento) que un auditor correría para comprobar que el runbook se aplicó.

## 11. Limpieza

```bash
rm -rf /tmp/aws-01-setup
```

Nada corriendo, nada en AWS.

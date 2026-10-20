# Actividad 01 — Diseñar jerarquía de Management Groups y escribir ADR

## 1. Identificación

- **ID:** `az-09-01-design-mg-structure-and-adr`
- **Tecnología:** `azure`
- **Módulo:** `az-09-multi-subscription-management-groups-azure-policy-landing-zone`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

Una startup de 20 personas (10 ingenieros, 3 data, 2 security, 5 negocio) va a entrar en Azure "en serio" después de un año en una única subscription. Dos workloads reales:

- **`checkout`**: API HTTP crítica, procesa pagos, SLA 99.9%, compliance PCI-light. Equipo backend de 4 personas. Debe estar accesible solo vía red corporativa (ExpressRoute en el futuro, Private Endpoints por ahora).
- **`analytics`**: pipeline con Databricks + dashboards internos (Power BI), no toca datos de pago, uso en horario laboral. 1 data engineer. Puede exponerse a internet con WAF.

Más:

- **Finance** quiere ver billing agregado y por entorno; usa el Billing Account EA del grupo.
- **Security** quiere logs centralizados en un Log Analytics workspace único y Defender for Cloud habilitado.
- Todas las cargas deben vivir en **Europa** (compliance), concretamente `westeurope` y `northeurope`.
- Los developers deben poder experimentar sin arrancar nada caro accidentalmente (no VMs GPU, no Azure Firewall en sandboxes).
- El equipo tiene **Entra ID P2** (ya pagan Office 365 E5), por lo que **PIM** está disponible.

Tu encargo: **diseñar la jerarquía de Management Groups, el inventario de subscriptions, las Azure Policies del baseline y el modelo de role assignments con PIM**, y documentarlo en un ADR que un equipo de 5 personas pueda leer y ejecutar en Fase 4 con Terraform (AVM ALZ) o Bicep.

**Importante**: no hay tenant Azure real. No se provisiona nada. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diseñar una jerarquía de MGs para una org pequeña y defender cada MG elegido.
- Decidir *"una app = una subscription"* vs *"una app = N subscriptions"* por workload y defender el criterio.
- Nombrar las Azure Policies del baseline, dónde las asignas y por qué.
- Mapear role assignments y grupos a MGs (no a tuplas usuario-subscription), con mención explícita de PIM eligible vs active.
- Escribir un ADR legible por un ingeniero que no estuvo en la discusión.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §3 MGs/CAF ALZ, §4-5 Azure Policy, §9 PIM, §10 patrones de subscriptions).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `az-01` (modelo), `az-02` (Entra ID + RBAC + Managed Identities), `az-03` (VNet/NSG).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-09-mg-adr
cd /tmp/az-09-mg-adr
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-MG-STRUCTURE.md`

Un **ADR** (Architecture Decision Record) es un documento corto y versionado. Formato que debes seguir:

```
# ADR 001 — Estructura de Management Groups y Landing Zone en Azure

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: qué problema resuelves, qué constraints hay — compliance EU,
PCI-light checkout, PIM disponible, etc.)

## Decisión
(La estructura que eliges, concreta: MGs, subscriptions, patrón por workload,
Azure Policies asignadas, role assignments con PIM. Idealmente con diagrama ASCII.)

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

- **Diagrama ASCII** de la jerarquía de MGs propuesta (con fences de código).
- **Al menos 4 subscriptions** nombradas (p. ej. `management`, `connectivity`, `identity`, `corp-checkout-prod`, `online-analytics-prod`...). **No uses IDs reales de subscription** (no uses GUIDs reales ni tenant IDs reales — usa nombres lógicos tipo `sub-corp-checkout-prod` o un placeholder `00000000-0000-0000-0000-000000000000`).
- **Al menos 3 Azure Policies** del baseline nombradas (`deny-locations`, `deny-public-ip`, `audit-diagnostic-settings`, `require-tags`, `deny-rdp-from-internet`...).
- **Al menos 3 roles** del catálogo built-in (`Owner`, `Contributor`, `Reader`, `Network Contributor`, `Key Vault Secrets User`, `Monitoring Reader`...).
- Mención explícita de **Management Groups** y de **Microsoft Entra ID** (o **Azure AD**).
- Mención explícita de **PIM** (Privileged Identity Management) con al menos un rol eligible.
- Mención explícita del patrón **CAF Landing Zone** o **Enterprise Scale** o **ALZ** (al menos uno de los tres términos).
- Una decisión explícita sobre **"una app = una subscription" vs "una app = N subscriptions"** para `checkout` y para `analytics`.
- Mención de **Europa** / `westeurope` / `northeurope` (compliance de región).

### 5.3 Entregable

Un archivo:

```
/tmp/az-09-mg-adr/ADR-MG-STRUCTURE.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-MG-STRUCTURE.md` existe y es coherente.
- El validador pasa en verde (`0 issue(s)` o `OK: estructura valida`).
- Un ingeniero externo puede leerlo y entender **qué** vas a montar y **por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no solo listada).
- **Reproducibilidad**: alguien en Fase 4 podría tomar este ADR y convertirlo a Terraform (AVM ALZ) o Bicep sin ambigüedades mayores.
- **Mantenibilidad**: Markdown válido, diagramas en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-09-mg-adr
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué `checkout` conviene en 3 subscriptions (dev/stg/prod) y `analytics` quizás en 1 sola o 2? ¿Qué criterio aplicaste?
2. Si en 2 años aparecen 10 workloads más, ¿tu jerarquía escala o la tendrías que rehacer?
3. ¿Dónde pondrías el pipeline de CI/CD (sub de *tools*)? ¿Por qué no en una sub de `Platform/Management`?
4. ¿Qué pasa el día que `Finance` pide ver *solo* el gasto de `corp-checkout-prod`? ¿Tu jerarquía lo hace fácil?
5. Si un auditor pregunta "muéstrame todos los role assignments efectivos de `developers` sobre `corp-checkout-prod`", ¿cómo le respondes?

## 10. Extensiones

- Añade una sección **"Fase 2"** al ADR describiendo cambios previsibles cuando la org crezca a 10+ workloads (p. ej. `Landing Zones/Corp/critical` vs `/Corp/internal`).
- Dibuja un **diagrama de assignments** (grupos × roles × MGs) como tabla.
- Añade una Azure Policy custom (fuera del baseline) justificada por el contexto PCI-light de `checkout` (p. ej. `deny-storage-public-network-access`).

## 11. Limpieza

```bash
rm -rf /tmp/az-09-mg-adr
```

No hay procesos ni infraestructura que detener.

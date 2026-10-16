# Actividad 02 — ADR: Crossplane vs Terraform-via-PR

## 1. Identificación

- **ID:** `plat-09-02-adr-crossplane-vs-tf-pr`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-09-self-service-infra-crossplane-and-templates`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Elegir entre **Crossplane** (K8s-native, composicional) y **Terraform-via-PR** (familiar, plan explícito, GitOps externo) es la decisión arquitectónica central de este módulo. **No hay respuesta universal**: la mejor elección depende del stack dominante, el tamaño del platform team, la deuda Terraform preexistente, el número de productos de plataforma a exponer y la cultura de la organización.

Esta actividad entrena el músculo de **defender una decisión** por 3 contextos distintos y de extraer **preguntas-criterio reutilizables** para futuros ADRs similares.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Comparar las dos opciones en **7 dimensiones** (stack dominante, curva de aprendizaje, debugging, GitOps, policy-as-code, overhead operacional, rollback).
- Decidir con criterio para 3 contextos distintos.
- Nombrar **5 preguntas-criterio** reutilizables, operables en una reunión de 15 min.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §2, §10, §11.
- Opcional pero recomendado: haber completado la actividad 01 para tener la experiencia física de Crossplane.
- Herramientas: `bash` + un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-09-02-adr
cd /tmp/plat-09-02-adr
```

Si prefieres otra ruta, pásala al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Los 3 contextos a decidir

Para cada uno escribe una sección en `ADR.md` con el formato que ves más abajo.

#### Contexto 1 — Scale-up SaaS K8s-first

> 300 ingenieros, 60 microservicios en K8s, Argo CD maduro, Kyverno en producción. El platform team de 6 personas quiere publicar en 12 meses un catálogo de 8 productos de plataforma (DB, bucket, cola, DNS, cert, cache, feature flag, repo nuevo). TF existe pero sólo para la infra base (VPCs, EKS, IAM).

#### Contexto 2 — Empresa industrial legacy con mucho Terraform

> 1500 ingenieros, 150 servicios heterogéneos (K8s, VMs, mainframe-adjacent). Terraform es la *lingua franca* desde hace 5 años, con un repo monorepo-ish de ~500k líneas y Atlantis estable. El platform team (4 personas) quiere publicar 2 productos: *nuevo microservicio* (repo + CI + chart) y *bucket*. No hay apetito por "aprender un nuevo paradigma".

#### Contexto 3 — Startup Series B multi-cloud

> 40 ingenieros, 15 servicios en EKS (prod) y GKE (staging), 2 ingenieros en el nascent platform team. Quieren publicar en 3 meses un catálogo de 4 productos: DB Postgres, bucket, cola, namespace. Experiencia TF intermedia, experiencia K8s profunda. Presupuesto limitado — no quieren un control plane extra que mantener si no amortiza.

### 5.3 Formato de cada contexto

Repite para los 3:

```
## Contexto N — <nombre>

**Decisión:** Crossplane | Terraform-via-PR | Híbrido

**Justificación (3–6 bullets):**
- criterio 1 (stack, equipo, curva, deuda TF, numero de productos…)
- criterio 2
- …

**Riesgo principal y mitigación:**
- riesgo concreto (ej.: "Crossplane v2 breaking change tras 6 meses sin team ownership")
- mitigación (ej.: "nombrar un owner on-call rotativo del XRD; cadencia upgrade trimestral")

**Qué cambiaría tu decisión:** 1–2 condiciones que invertirían la elección.
```

### 5.4 Síntesis final

Añade al final de `ADR.md` dos secciones:

```
## Comparativa en 7 dimensiones

Una tabla Markdown de 7 filas x 3 columnas (dimensión | Crossplane | Terraform-via-PR).
Dimensiones: stack dominante, curva de aprendizaje, debugging, GitOps,
policy-as-code, overhead operacional, rollback.

## 5 preguntas-criterio reutilizables

Numeradas 1..5. Cortas. Operables (un lead puede contestarlas en una reunión).
Ejemplo de forma (no copies literal):
  1. ¿Cuántos productos de plataforma distintos prevemos publicar en 12 meses?
```

### 5.5 Entregable

Un archivo:

```
/tmp/plat-09-02-adr/ADR.md
```

con los 3 contextos + la tabla de 7 dimensiones + las 5 preguntas-criterio numeradas.

## 6. Resultado esperado

- `ADR.md` existe y es coherente.
- Cada contexto tiene decisión, justificación, riesgo+mitigación, condición de inversión.
- La tabla comparativa tiene 7 filas (más header + separador).
- Las 5 preguntas numeradas están.
- `bash tests/validate.sh /tmp/plat-09-02-adr` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión defendida con criterios técnicos, no "me gusta más Crossplane".
- **Reproducibilidad**: cualquiera que lea el ADR entiende por qué.
- **Mantenibilidad**: Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-09-02-adr
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. En el contexto 2, un platform engineer propone adoptar Crossplane "para el futuro". ¿Cómo le respondes sin cerrar la puerta pero sin aceptar el costo?
2. En el contexto 3, ¿cambiaría tu decisión si el equipo platform fuera de 6 personas en lugar de 2? ¿Por qué?
3. Un patrón **híbrido** (TF para infra base, Crossplane para productos namespaced) ¿tiene sentido? ¿En qué contexto?
4. Si eliges Crossplane, ¿qué 3 cosas haces el día 1 para que la decisión no sea una "trampa a futuro"?
5. ¿Qué métrica usarías tras 6 meses para saber si la elección fue correcta?

## 10. Extensiones

- Añade un **4.º** contexto propio (de tu organización real si puedes).
- Diseña un plan de 90 días para migrar de TF-via-PR a Crossplane para 1 producto (DB Postgres). Qué dejarías igual, qué cambiaría.
- Escribe la **política de deprecation** del XRD si eliges Crossplane: cómo pasas `v1alpha1 → v1beta1 → v1` sin romper claims en producción.

## 11. Limpieza

```bash
rm -rf /tmp/plat-09-02-adr
```

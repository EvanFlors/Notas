# Actividad 02 — ADR: Kubernetes plugin de Jenkins vs ARC de GitHub Actions

## 1. Identificación

- **ID:** `jk-05-02-arc-vs-jenkins-k8s-adr`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-05-agents-distributed-builds-kubernetes-plugin`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** architecture (independiente respecto a la actividad 01)

## 2. Contexto

Tu empresa tiene:

- Un **Jenkins LTS** on-prem con ~120 pipelines activos, Shared Libraries maduras.
- Un cluster **Kubernetes** nuevo, provisionado por el Platform team, actualmente infrautilizado.
- Los repos están en **GitHub Enterprise Cloud** (SaaS, no GHES).
- El equipo de Platform propone **dos opciones** para los agents de CI:
  - **A)** Jenkins + **Kubernetes plugin**: dejar el controller como está, migrar los agents de VMs permanentes a Pods efímeros.
  - **B)** Migrar progresivamente a **GitHub Actions + ARC** (Actions Runner Controller): nuevo plano de control (GitHub), agents en el mismo cluster, Shared Libraries portadas a reusable workflows en varios trimestres.

Tu encargo: escribir un **ADR** eligiendo una opción (o un camino híbrido explícito) y justificarla.

## 3. Objetivos

Al terminar deberías poder:

- Comparar ambos modelos en al menos: control plane, networking, escalado, gobernanza, inercia operativa, coste.
- Elegir una opción y defender la decisión contra ambos extremos ("todo a Jenkins" / "migra todo ya a ARC").
- Documentar en formato ADR estándar con alternativas explícitas.

## 4. Prerrequisitos

- `jk-02` completo.
- Curso **kubernetes** ≥ Nivel 2.
- Haber leído `../../theory/lesson.md` §7 (comparación ARC) y `examples/03-ephemeral-vs-permanent-tradeoffs/`.

**Costos**: ninguno. Documento Markdown.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/jk-05-arc-adr
cd /tmp/jk-05-arc-adr
```

### 5.2 Escribe `ADR-ARC-VS-K8S-PLUGIN.md`

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- Mención explícita de **Jenkins** y **Kubernetes plugin**.
- Mención explícita de **ARC** (Actions Runner Controller) y **GitHub Actions**.
- Mención de al menos **3 dimensiones de comparación** (p. ej. control plane, networking, escalado, gobernanza, inercia, coste).
- Mención de **Shared Libraries** (porque son el activo que condiciona la migración).
- Mención de **Pods efímeros** (modelo común en ambas opciones).
- Al menos **2 alternativas** explícitamente descartadas (p. ej. permanent VMs, SaaS runners GitHub, GitLab CI).
- Una **decisión concreta** (A, B, o híbrido con fases y criterios de corte).

### 5.3 Entregable

```
/tmp/jk-05-arc-adr/ADR-ARC-VS-K8S-PLUGIN.md
```

## 6. Resultado esperado

- Validador en verde.
- Un ingeniero externo entiende qué eliges y por qué.
- La decisión es defendible contra ambos extremos.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada dimensión está discutida, no solo listada.
- **Reproducibilidad**: la fase 2 (si eliges híbrido) tiene criterios de corte observables.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-05-arc-adr
```

## 9. Preguntas de reflexión

1. Si tu empresa migrara mañana de GitHub a GitLab, ¿tu decisión cambia?
2. ¿Qué pasa con las Shared Libraries en el escenario B? ¿Las portas, las congelas, las retiras?
3. ¿Dónde queda el logging de ejecuciones históricas si retiras Jenkins?
4. ¿Qué métrica te haría abortar la migración y volver a Jenkins puro?
5. ¿Y si el controller Jenkins no es tuyo (lo opera otro equipo)? ¿Cómo cambia la elección?

## 10. Extensiones

- Añade un diagrama ASCII de ambos planos (controller vs cluster) para visualizar.
- Añade una sección "Fase 2" con hitos a 3, 6 y 12 meses si eliges híbrido.
- Añade una tabla de riesgos con probabilidad × impacto y mitigación.

## 11. Limpieza

```bash
rm -rf /tmp/jk-05-arc-adr
```

# Starter — jk-05-02-arc-vs-jenkins-k8s-adr

Esta actividad es **independiente**: entregable único es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y `../../theory/lesson.md` §7.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-05-arc-adr
   cd /tmp/jk-05-arc-adr
   ```
3. Crea `ADR-ARC-VS-K8S-PLUGIN.md` con las 6 secciones obligatorias (Estado, Contexto, Decisión, Consecuencias, Alternativas + encabezado ADR).
4. Incluye en la Decisión:
   - Mención explícita de Jenkins + Kubernetes plugin y de GitHub Actions + ARC.
   - Al menos 3 dimensiones comparadas (control plane, networking, escalado, gobernanza, inercia, coste).
   - Mención de Shared Libraries y Pods efímeros.
   - Al menos 2 alternativas descartadas.
5. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/05-agents-distributed-builds-kubernetes-plugin/activities/02-arc-vs-jenkins-k8s-adr/tests/validate.sh /tmp/jk-05-arc-adr
   ```
6. Compara con `../solution/REFERENCE.md`.

## Plantilla opcional

```markdown
# ADR 001 — Modelo de agents de CI: Jenkins + Kubernetes plugin vs GitHub Actions + ARC

## Estado
Propuesto

## Contexto
<Jenkins LTS legacy, cluster K8s nuevo, repos en GitHub Enterprise Cloud, Shared Libraries maduras>

## Decisión
<A, B o híbrido con fases>

### Dimensiones comparadas
- Control plane: ...
- Networking: ...
- Escalado: ...
- Gobernanza: ...
- Inercia operativa: ...
- Coste: ...

## Consecuencias
### Positivas
### Negativas

## Alternativas descartadas
### Alt A: ...
### Alt B: ...
```

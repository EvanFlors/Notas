# Módulo 14 — Infraestructura y DevOps

## Propósito

El código que no está en producción no genera valor. La infraestructura es el puente entre el desarrollo y la operación. Contenedores, orquestación, CI/CD, y cloud son las herramientas que llevan tu código a producción de forma segura y repetible.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 14.1 | Contenedores | Docker internals (namespaces, cgroups, overlay fs), Dockerfile best practices |
| 14.2 | Orquestación | Kubernetes (pods, deployments, services), auto-scaling, Helm |
| 14.3 | CI/CD | Pipelines, deployment strategies, GitOps, IaC |
| 14.4 | Cloud | Compute, networking, storage, managed services |

## Dependencias

```
Módulo 1 (OS: namespaces, cgroups) → Módulo 14 (containers usan estas primitivas)
Módulos 1-13 → Módulo 14 (infraestructura para deployear todo lo aprendido)
```

<!-- TODO-STUDENT: delete this line once the ADR is complete; the validator looks for its absence. -->
# ADR — Operator vs Helm para operar el Collector

> Completa este documento. El validador verifica que las 4 secciones existan, que esta línea TODO-STUDENT haya sido eliminada, y que el contenido no sea trivial.

## 1. Contexto

Describe la situación (N instancias esperadas, modos del Collector requeridos, si quieres auto-inject, equipos consumidores, cómo despliegas hoy — Argo/Flux/Jenkins/manual).

Ejemplo:

> Plataforma interna con 1 cluster EKS, 40 microservicios Python/Java, 1 gateway + 1 agent DaemonSet,
> auto-inject deseado para Python, Argo CD como GitOps.

## 2. Decisión

¿Operator o Helm? Decide una.

## 3. Justificación

Al menos **3 criterios concretos** con cómo se materializan en tu contexto. Ejemplo de criterios: drift protection, cantidad de CRs necesarios, dependencia extra (cert-manager), curva, upgrade story, blast radius, soporte de Target Allocator, auto-inject, debugability.

Para cada criterio: **cómo lo satisface** la opción elegida y **qué cedes** respecto a la otra.

## 4. Equivalencias y red flags

- **Equivalencia del rollout ejercicio 1**: ¿cómo lo harías en Helm? Comandos.
- **3 red flags** que te harían **rechazar** el Operator en un contexto distinto.
- Rollback: cómo lo ejecutas en ambas opciones.

---

(Opcional) Anota aquí la salida de los `kubectl get rs` antes/después del upgrade de imagen.

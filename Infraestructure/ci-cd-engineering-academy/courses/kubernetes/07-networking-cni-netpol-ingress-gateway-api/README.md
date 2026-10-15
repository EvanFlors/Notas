# k8s-07 — Networking: CNI, NetworkPolicy, Ingress y Gateway API

## Identificación

- **ID:** `k8s-07-networking-cni-netpol-ingress-gateway-api`
- **Curso:** `kubernetes`
- **Nivel:** intermedio
- **Duración estimada:** 6 h
- **Prerrequisitos:** `k8s-04-services-and-dns`; T-3 Networking (TCP/IP, DNS, HTTP, TLS, NAT).

## Objetivo

Controlar el tráfico **este-oeste** (Pod ↔ Pod) y **norte-sur** (externo ↔ Pod) con las primitivas correctas: elegir un **CNI** adecuado, aplicar **NetworkPolicy** con patrón **default-deny** + reglas explícitas, y exponer workloads con **Ingress** o, preferentemente, con la **Gateway API** (sucesor de Ingress).

## Alcance

Este módulo cubre:

- **Modelo de red Kubernetes**: todo Pod puede alcanzar a todo Pod **sin NAT** dentro del cluster — por default (y por qué eso es un problema de seguridad por default-open).
- **CNI** y plugins populares: Calico, Cilium (eBPF), Flannel, AWS VPC CNI, GKE Dataplane v2. Qué resuelve cada uno y qué trade-offs implica.
- **NetworkPolicy**: `ingress`/`egress`, `podSelector`/`namespaceSelector`/`ipBlock`, patrón **default-deny** y reglas explícitas aditivas.
- **Ingress** (API clásica L7) vs **Gateway API** (sucesor, roles separados). Qué los diferencia y cuándo migrar.
- **Gateway API**: `GatewayClass`, `Gateway`, `HTTPRoute` (y mención de `TCPRoute`/`TLSRoute`/`GRPCRoute`). Separación de roles plataforma vs equipo de app.
- **Controllers populares**: ingress-nginx, Traefik, Contour, Istio Gateway, **Envoy Gateway**.
- **mTLS**: introducción (service mesh queda para Nivel 4).
- **DNS avanzado**: CoreDNS plugins (`forward`, `cache`, `rewrite`, `hosts`, `kubernetes`).

Lo que **no** cubre (vendrá después):

- Service mesh completo (Istio/Linkerd/Cilium Service Mesh) → `k8s-18`.
- Observabilidad L7 profunda (Hubble, Kiali) → `k8s-15`.
- Firma e imagen policy sobre controllers → `k8s-16`.
- Multi-cluster service discovery → `k8s-17`.

## Materiales

- **`theory/lesson.md`** — lección profunda en 12 secciones (~3 h de lectura + exploración).
- **`examples/`** — demostraciones reproducibles:
  - `01-default-deny-netpol/` — aplicar default-deny en un namespace y luego habilitar tráfico explícito.
  - `02-ingress-nginx-tls/` — instalar ingress-nginx y publicar una app con TLS (cert autofirmado).
  - `03-gateway-api-http-route/` — instalar CRDs de Gateway API y definir `GatewayClass`/`Gateway`/`HTTPRoute`.
- **`activities/`**:
  - `01-isolate-ns-with-netpol/` — **guided-lab**: aislar un namespace con default-deny y abrir solo lo necesario (app → Postgres, cliente → app).
  - `02-publish-with-gateway-api/` — **independent**: escribir manifiestos Gateway API válidos para publicar una app con HTTPRoute y path matching.
- **`resources/links.md`** — documentación oficial y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué el modelo de red K8s es "default-open" y por qué eso contradice least-privilege. Diferenciar CNI, NetworkPolicy, Ingress y Gateway API (son 4 capas distintas). Describir qué separa Gateway API de Ingress (roles, extensibilidad tipada). |
| Operativa | Aplicar un `default-deny` + `allow` aditivos en un namespace. Instalar un ingress controller y publicar una app con TLS. Escribir `GatewayClass`/`Gateway`/`HTTPRoute` válidos. Depurar "mi NetworkPolicy no deja pasar". |
| Arquitectónica | Elegir CNI por caso de uso (Calico vs Cilium vs managed). Diseñar la política de red de un namespace con app + Postgres + cache. Decidir Ingress vs Gateway API para un proyecto nuevo. |

## Criterios de evaluación

- **Diseño**: política de red escrita para un namespace con app + Postgres + cache (quién habla con quién, egress a DNS, egress a internet solo donde se justifica).
- **Operativo**: cluster local con `default-deny` aplicado + app publicada vía Gateway API (manifiestos válidos) con TLS.
- `tests/validate.sh` de cada actividad pasa (reporta `SKIP` si falta `kind`/`kubectl`).

## Kubernetes: requisitos y comportamiento

- **Requiere** `kind` y `kubectl` instalados. Si falta cualquiera, los validadores reportan `SKIP` (no `FAIL`).
- **Default CNI de `kind` (`kindnet`) NO enforce NetworkPolicy**. Para probar NetworkPolicy en kind hay que instalar **Calico** o **Cilium** en el cluster. Los ejemplos y actividades que usan NetworkPolicy lo instalan automáticamente desde el bootstrap.
- **Gateway API** no está incluida por default en Kubernetes; hay que instalar los **CRDs** (`kubectl apply -f` desde el repo `kubernetes-sigs/gateway-api`) y un **controller** (Envoy Gateway, Istio, Contour, etc.). La Actividad 02 **solo valida los manifiestos** (no requiere traffic real) para mantener la actividad ligera; el ejemplo 03 muestra cómo instalar un controller real como extensión opcional.
- No se tocan secretos reales. TLS usa certificados **autofirmados** generados on-the-fly.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada sin consultar externos).
2. Reproduce `examples/01-default-deny-netpol/`, luego `02-ingress-nginx-tls/`, luego `03-gateway-api-http-route/`.
3. Haz la actividad `01-isolate-ns-with-netpol/` (guided-lab).
4. Haz la actividad `02-publish-with-gateway-api/` sin consultar la solución.
5. Responde las preguntas de evaluación del final de la lección sin re-leer.

## Siguiente

→ `k8s-08-storage-pv-pvc-storageclass-csi`: persistir estado con PV/PVC/StorageClass/CSI.

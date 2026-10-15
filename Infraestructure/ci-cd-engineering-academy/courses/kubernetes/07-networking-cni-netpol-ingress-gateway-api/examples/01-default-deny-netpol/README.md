# Ejemplo 01 — Default-deny NetworkPolicy + allow explícito

## Concepto que demuestra

Qué pasa cuando aplicas un **`default-deny`** en un namespace: todo tráfico se corta, incluso DNS. Y cómo lo abres de forma mínima: primero DNS, luego Pod-a-Pod específico.

## Por qué importa

El modelo K8s es **default-open**. Para producción esto no sirve. El idioma profesional es `default-deny` por namespace + allows aditivos.

## Objetivo

Al terminar sabrás:

- Crear un cluster `kind` con un CNI que **sí** enforce NetworkPolicy (Calico).
- Aplicar un `default-deny` para `Ingress` y `Egress`.
- Observar que incluso `nslookup kubernetes.default` falla.
- Añadir allow DNS → la resolución vuelve.
- Añadir allow explícito `client → server` → el tráfico vuelve, pero solo para esa pareja.

## Prerrequisitos

- `kind` y `kubectl` instalados.
- Docker corriendo (lo necesita `kind`).
- ~500 MB para la imagen del nodo + ~200 MB para Calico.
- Puertos libres: ninguno (todo es tráfico interno al cluster).

## Archivo del ejemplo

`files/run-demo.sh`. Léelo primero; luego lo corres.

## Ejecución

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/examples/01-default-deny-netpol/files/run-demo.sh
```

El script:

1. Crea el cluster `kind` `k8s07-netpol` con `disableDefaultCNI: true`.
2. Instala **Calico** como CNI (sí enforce NetworkPolicy).
3. Crea namespace `app` y dos Deployments: `server` (nginx) y `client` (busybox).
4. Verifica que `client → server` **funciona** sin policies.
5. Aplica `default-deny-all` → ni DNS ni TCP responden.
6. Aplica `allow-dns` → DNS vuelve, TCP a `server` sigue cortado.
7. Aplica `allow-client-to-server` → TCP vuelve pero solo entre esos dos.
8. Deja el cluster corriendo para que explores (hay nota al final sobre cómo borrarlo).

## Resultado esperado

```
== 1. Sin policies ==
client -> server:80 : OK
nslookup kubernetes.default : OK

== 2. default-deny-all ==
client -> server:80 : FAIL (timeout)
nslookup kubernetes.default : FAIL (resolve fail)

== 3. + allow-dns ==
client -> server:80 : FAIL (timeout)
nslookup kubernetes.default : OK

== 4. + allow-client-to-server ==
client -> server:80 : OK
```

## Interpretación

- Sin policy, el default-open deja todo pasar. Es cómodo y peligroso.
- Con `default-deny`, incluso DNS falla: por eso la primera regla profesional de red es permitir egress a `kube-system/k8s-app=kube-dns` en UDP/TCP 53.
- Con allow específico, el principio de least-privilege se cumple: `client` ve a `server`, pero cualquier otro Pod del namespace no.

## Errores frecuentes

- **"NetworkPolicy applied but client still reaches server"**: estás en un cluster con `kindnet`/`flannel`, que no enforce policies. Verifica con `kubectl get pods -n kube-system | grep -E 'calico|cilium'`.
- **"Nothing resolves even with allow-dns"**: el namespace de kube-dns puede no tener el label estándar; verifica con `kubectl get ns kube-system --show-labels` y ajusta el `namespaceSelector`.

## Limpieza

```bash
kind delete cluster --name k8s07-netpol
```

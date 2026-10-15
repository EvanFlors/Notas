# Actividad 01 — Aislar un namespace con NetworkPolicy (default-deny + allows)

## 1. Identificación

- **ID:** `k8s-07-01-isolate-ns-with-netpol`
- **Tecnología:** `kubernetes`
- **Módulo:** `07-networking-cni-netpol-ingress-gateway-api`
- **Dificultad:** intermediate
- **Duración estimada:** 75 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a aislar un namespace `shop` con el patrón **default-deny** y abrir **solo** el tráfico necesario para que la app funcione:

```
client (ns: shop, label: role=client)  -->  api (ns: shop, label: role=api)
                                             api  -->  postgres (ns: shop, label: role=db)
                                             (TCP 5432)
                                             (nadie puede llegar a postgres salvo api)
                                             (todo el namespace puede resolver DNS)
```

Tráfico que **no** quieres: `client` → `postgres` directo; cualquier Pod sin label `role=api` llegando a `postgres`; egress a internet desde `postgres` (contención en caso de compromiso).

## 3. Objetivos

- Preparar un cluster `kind` **con Calico** (NetworkPolicy enforced).
- Desplegar los Pods `client`, `api` (nginx proxy), `postgres`.
- Aplicar en `shop`:
  - `default-deny-all` (ingress + egress).
  - `allow-dns` (egress UDP/TCP 53 a kube-dns).
  - `allow-client-to-api` (ingress a `api` desde `client`; egress en `client` a `api`).
  - `allow-api-to-postgres` (ingress a `postgres` desde `api`; egress en `api` a `postgres`).
- Verificar con pruebas positivas y negativas.

## 4. Prerrequisitos

- `kind`, `kubectl` instalados.
- `docker` corriendo.
- ~500 MB para imagen del nodo + Calico (~200 MB).
- Puertos: ninguno externo (todo intra-cluster).
- Costo: $0.

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/01-isolate-ns-with-netpol/starter/bootstrap.sh
```

Esto:

1. Crea el cluster `k8s07-act1` con `disableDefaultCNI: true`.
2. Instala Calico.
3. Crea namespace `shop` y los Deployments `client`, `api`, `postgres`.
4. Crea el scratch dir `/tmp/k8s07-act1/` con notas y plantillas vacías de NetworkPolicy.

### 5.2 Diseña y aplica las policies

En `/tmp/k8s07-act1/policies/` tienes 4 archivos con **plantillas vacías comentadas**:

- `00-default-deny.yaml`
- `01-allow-dns.yaml`
- `02-allow-client-to-api.yaml`
- `03-allow-api-to-postgres.yaml`

Edítalos (hay pistas en los comentarios de cada archivo) y aplica:

```bash
kubectl apply -f /tmp/k8s07-act1/policies/
```

**Pistas** (no te damos el YAML completo):

- `default-deny` selecciona **todos** los Pods del namespace y lista `Ingress` y `Egress` en `policyTypes` sin reglas.
- `allow-dns` tiene `podSelector: {}` y abre **egress** a `namespaceSelector: kubernetes.io/metadata.name=kube-system` + `podSelector: k8s-app=kube-dns` en UDP/53 **y** TCP/53.
- `allow-client-to-api`: dos partes (ingress en `api`, egress en `client`) o un único NetworkPolicy por lado. El puerto de `api` es TCP/80.
- `allow-api-to-postgres`: ingress en `postgres` desde `role=api`, egress en `api` a `role=db`. Puerto TCP/5432. **No** abrir egress a internet desde `postgres`.

### 5.3 Verifica manualmente

```bash
# Positivo: client -> api (TCP 80) -> OK
kubectl -n shop exec deploy/client -- wget -qO- --timeout=3 http://api/ | head -1

# Positivo: api -> postgres (TCP 5432) -> OK
kubectl -n shop exec deploy/api -- nc -zv -w3 postgres 5432

# Negativo: client -> postgres (TCP 5432) -> timeout
kubectl -n shop exec deploy/client -- nc -zv -w3 postgres 5432 || echo "bloqueado (correcto)"

# Positivo: todos pueden resolver DNS
kubectl -n shop exec deploy/client -- nslookup -timeout=3 kubernetes.default
```

### 5.4 Valida

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/01-isolate-ns-with-netpol/tests/validate.sh
```

Debe reportar `RESULT: N/N checks OK.`.

### 5.5 Dibuja

En `/tmp/k8s07-act1/diagram.txt` (ya existe como placeholder), dibuja en ASCII el namespace `shop`, los 3 Pods, las flechas permitidas, y los allow/deny.

## 6. Resultado esperado

- `shop` tiene **4 NetworkPolicy** aplicadas (nombres libres pero deben cubrir las 4 funciones).
- Pruebas positivas pasan; pruebas negativas bloquean.
- `postgres` **no** puede hacer egress a internet (prueba: `kubectl -n shop exec deploy/postgres -- getent hosts google.com` — DNS no debe resolver salvo que explícitamente abras DNS para `role=db`; sin allow específico, no debería).
- Diagrama no trivial en `/tmp/k8s07-act1/diagram.txt`.

## 7. Criterios de aceptación

- [ ] 4 (o más) NetworkPolicies en namespace `shop`.
- [ ] `client -> api` funciona.
- [ ] `api -> postgres` funciona.
- [ ] `client -> postgres` **bloqueado**.
- [ ] DNS resuelve desde los Pods que lo necesitan.
- [ ] Diagrama presente y editado.

## 8. Validación

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/activities/01-isolate-ns-with-netpol/tests/validate.sh
```

Si falta `kind`/`kubectl`/`docker`, el validador imprime `SKIP` y sale con 0.

## 9. Preguntas de reflexión

1. ¿Qué pasó la primera vez que aplicaste `default-deny` sin `allow-dns`?
2. ¿Por qué `allow-dns` requiere **UDP y TCP** en el puerto 53?
3. ¿Qué diferencia hay entre poner `namespaceSelector` y `podSelector` en el **mismo** item vs items separados dentro de `from:`?
4. Si quisieras permitir a `api` llamar a una API externa en `api.stripe.com`, ¿qué opciones tienes? ¿Qué CNI(s) permiten egress por FQDN?
5. Diseña 1 regla extra que mejorarías tras un threat-model: ¿qué cambiarías si `postgres` guardara datos regulados?

## 10. Extensiones

- **E1** — Añade un `cache` (redis) con las policies que necesite (solo `api` lo llama).
- **E2** — Instala Cilium (en lugar de Calico) y escribe la misma política con `CiliumNetworkPolicy` con una regla L7 (p. ej. restringir `api` a `GET /` nada más).
- **E3** — Mide con `hubble observe` (o logs del CNI) los paquetes bloqueados en un intento `client -> postgres`.

## 11. Limpieza

```bash
kind delete cluster --name k8s07-act1
rm -rf /tmp/k8s07-act1
```

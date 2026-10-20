# Ejemplo 02 — ingress-nginx con TLS (cert autofirmado)

## Concepto que demuestra

Instalar un **ingress controller** (ingress-nginx) en un cluster `kind` y publicar una app con **TLS** terminado en el controller. Vemos cómo encajan:

```
cliente HTTPS -> [kind-node:443] -> ingress-nginx -> Service -> Pods
```

## Objetivo

- Levantar ingress-nginx en kind con `extraPortMappings` para 80/443.
- Generar un cert autofirmado y crear el Secret `kubernetes.io/tls`.
- Crear un `Ingress` con TLS y `ssl-redirect`.
- Probar HTTP → redirige a HTTPS; HTTPS → responde 200 con el cert esperado.

## Prerrequisitos

- `kind` y `kubectl` instalados.
- `openssl` para generar el cert.
- Docker corriendo.
- Puertos del host libres: **80** y **8443** (el 443 lo mapeamos a 8443 para no pedir sudo).

## Archivo del ejemplo

`files/run-demo.sh`. Léelo primero; luego lo corres.

## Ejecución

```bash
bash courses/kubernetes/07-networking-cni-netpol-ingress-gateway-api/examples/02-ingress-nginx-tls/files/run-demo.sh
```

El script:

1. Crea cluster `k8s07-ingress` con mapeo `80 -> 80` y `443 -> 8443`.
2. Instala **ingress-nginx** manifest oficial para kind.
3. Despliega `web` (Deployment nginx + Service).
4. Genera cert autofirmado para `app.example.local` y crea el Secret `web-tls`.
5. Aplica un `Ingress` con TLS y `ssl-redirect`.
6. Prueba `curl -k https://localhost:8443/ -H 'Host: app.example.local'` → 200.

## Resultado esperado

```
HTTP -> 308 Permanent Redirect (ssl-redirect)
HTTPS -> 200 (<title>Welcome to nginx!</title>)
Cert subject: CN=app.example.local
```

## Interpretación

- El cert autofirmado dispara warning en navegadores — en lab usamos `-k` en curl.
- `ssl-redirect` lo mete el controller leyendo la annotation; el redirect es 308.
- Un `Ingress` **puede** declarar varios hosts y rutas; solo demostramos el caso mínimo.

## Errores frecuentes

- "404": el `Host` del request no coincide con `rules.host`. Usa `--resolve` o `-H "Host: ..."`.
- "503": el Service no tiene endpoints. `kubectl get endpoints web`.
- "no route to host 8443": `kind` no fue creado con `extraPortMappings`. Hay que recrearlo.

## Limpieza

```bash
kind delete cluster --name k8s07-ingress
```

# Actividad 01 — kind + overlay dev end-to-end (guided-lab)

## Objetivo

Levantar un cluster kind local, instalar el ingress controller y
aplicar el overlay `dev` del capstone. Al cerrar: un rollout exitoso,
HPA presente, PDB presente, NetworkPolicy aplicada.

## Pasos

1. Desde la raiz de la stage:
   ```bash
   kind create cluster --config kind/kind-config.yaml --name capstone
   ```
2. Instala NGINX ingress para kind:
   ```bash
   kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
   kubectl wait --namespace ingress-nginx --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller --timeout=180s
   ```
3. Dry-run de los 3 overlays:
   ```bash
   for env in dev staging prod; do
     kubectl apply --dry-run=client --validate=false -k k8s/overlays/$env
   done
   ```
4. Aplica dev de verdad:
   ```bash
   kubectl apply -k k8s/overlays/dev
   kubectl -n app-dev rollout status deploy/capstone-api --timeout=120s
   ```
5. Smoke:
   ```bash
   bash tests/smoke.sh
   ```

## Validacion

```bash
bash tests/validate.sh
```

Debe reportar 0 fallas.

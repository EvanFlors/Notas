# Starter — gcp-07-02-workload-identity-federation-walkthrough

Actividad independiente: produces 1 YAML + 1 script bash + 1 ADR Markdown.

## Pasos

1. Lee `../README.md` completo y recorre `../../../examples/02-workload-identity-walkthrough/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-07-02-wif/k8s /tmp/gcp-07-02-wif/scripts
   cd /tmp/gcp-07-02-wif
   ```
3. Copia los esqueletos:
   - `starter/k8s/serviceaccount-and-deployment.yaml` → `/tmp/gcp-07-02-wif/k8s/`
   - `starter/scripts/provision-wif.sh` → `/tmp/gcp-07-02-wif/scripts/`
4. Completa los TODOs en los dos archivos.
5. Haz el script ejecutable:
   ```bash
   chmod +x /tmp/gcp-07-02-wif/scripts/provision-wif.sh
   bash -n /tmp/gcp-07-02-wif/scripts/provision-wif.sh && echo "syntax OK"
   ```
6. (Opcional) Valida el YAML con kubectl:
   ```bash
   kubectl apply --dry-run=client -f /tmp/gcp-07-02-wif/k8s/serviceaccount-and-deployment.yaml
   ```
   O con `kind`:
   ```bash
   kind create cluster --name wif-test
   kubectl create namespace checkout
   kubectl apply -f /tmp/gcp-07-02-wif/k8s/serviceaccount-and-deployment.yaml
   kubectl get sa -n checkout
   kind delete cluster --name wif-test
   ```
7. Escribe `WORKLOAD-IDENTITY-ADR.md` con las 6 secciones (ADR, Estado, Contexto, Decisión, Consecuencias, Alternativas).
8. Valida:
   ```bash
   bash <ruta-repo>/courses/gcp/07-gke-and-autopilot/activities/02-workload-identity-federation-walkthrough/tests/validate.sh /tmp/gcp-07-02-wif
   ```
9. Compara con `../solution/REFERENCE.md`.

## Nota

**No ejecutes el script `provision-wif.sh`** contra un project GCP real. Es una referencia de los comandos que la plataforma correría; se valida con `bash -n` y con `grep`.

**Usa placeholders**: `my-project-123`, `checkout-app`, `checkout`. Nunca IDs reales.

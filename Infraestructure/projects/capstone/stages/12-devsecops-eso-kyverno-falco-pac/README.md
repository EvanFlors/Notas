# Capstone — Etapa 12: DevSecOps completo (ESO + Kyverno + Falco + Policy as Code)

> Fase 5 del programa · Dominios tocados: D9 (seguridad), D8 (Kubernetes), D5 (CI).
> Esta etapa asume cerradas las etapas 1–11 (app + CI + imagen firmada + Terraform + K8s + Argo CD + GitOps multi-ambiente + observabilidad).
> Entorno: `kind` local es suficiente para todos los controles; EKS/GKE/AKS funcionan sin cambios.

---

## 1. Resumen de la etapa

**Objetivo.** Clausurar el flanco de DevSecOps "en tiempo de admisión y runtime": los secretos entran al cluster vía External Secrets Operator (ESO) desde Vault, Kyverno rechaza en el admission webhook todo pod que no esté firmado, que no tenga labels obligatorias o que viole la baseline PSS, Falco observa syscalls para detectar comportamiento sospechoso en runtime, y un job de GitHub Actions corre `conftest` sobre los manifiestos de Kubernetes antes de que lleguen a `main`. Nada de "lo auditamos manualmente".

**Delta vs. etapa 11.** La etapa 11 introdujo Prometheus/Grafana/OTel/Loki y SLOs; sabíamos qué pasaba, pero no bloqueábamos nada. Aquí añadimos tres capas de control: **shift-left** (conftest en CI), **admission** (Kyverno) y **runtime** (Falco), y sustituimos los `Secret` plano gestionados por humanos por `ExternalSecret` reconciliados.

**Fuera de scope.**

- Vault en modo HA con auto-unseal → en producción, aquí usamos `vault server -dev` o `kind`-local.
- Falco Talon / autorespuesta automática → sólo detectamos y alertamos.
- Firma de los propios `ClusterPolicy` con cosign (policy-as-signed-code) → iteración siguiente.
- Comparar Kyverno vs. OPA Gatekeeper en profundidad → ya se discute en el ADR del curso DevSecOps.
- Backstage, scorecards y DORA → Etapa 13.

---

## 2. Arquitectura al cierre de esta etapa

```
                        +-------------------+
                        |  GitHub Actions   |
                        |  policy-check.yml |
                        | (conftest + opa)  |
                        +---------+---------+
                                  | PR gate
                                  v
                        +---------+---------+        +---------------------+
                        |     main branch   | -----> |   Argo CD sync      |
                        +---------+---------+        +----------+----------+
                                                                |
                                                                v
+---------------------+     +----------------------------------------+
|   Vault (dev)       |     |   Kubernetes cluster (kind / EKS)      |
|   kv/capstone/*     |     |                                        |
+----------+----------+     |   +------------+   +------------------+|
           ^                |   |   ESO      |-->|  Secret (synced) ||
           | kube-auth      |   +------------+   +------------------+|
           |                |          ^                             |
           |                |          | ExternalSecret               |
           |                |   +------+------+                       |
           +----------------+---|  app pod    |                       |
                            |   |  (FastAPI)  |                       |
                            |   +------+------+                       |
                            |          |                              |
                            |          | syscalls                     |
                            |          v                              |
                            |   +-------------+                       |
                            |   |   Falco     |---> alerts (stdout /  |
                            |   | DaemonSet   |     Loki / webhook)   |
                            |   +-------------+                       |
                            |                                         |
                            |   +----------------------------------+  |
                            |   |  Kyverno (admission webhook)     |  |
                            |   |  - verify-images (cosign keyless)|  |
                            |   |  - required-labels               |  |
                            |   |  - baseline-restricted (PSS)     |  |
                            |   +----------------------------------+  |
                            +----------------------------------------+
```

**Entradas.** Pull requests con cambios a manifiestos K8s/Helm. Peticiones del cluster al admisor Kyverno. Syscalls recogidos por Falco.
**Salidas.** PRs bloqueados en CI, pods rechazados en admisión, eventos Falco, `Secret` sincronizados desde Vault.
**Resource list.**

- `external-secrets` namespace + Deployment ESO (Helm `external-secrets/external-secrets`, v0.9+).
- `ClusterSecretStore` apuntando a Vault.
- `ExternalSecret` por cada secreto de la app.
- `kyverno` namespace + Helm chart `kyverno/kyverno` (v3.x).
- 3 `ClusterPolicy` (verify-images, required-labels, baseline-restricted).
- `falco` namespace + Helm chart `falcosecurity/falco` (modern-bpf driver).
- GitHub Actions job `policy-check` corriendo en cada PR.

---

## 3. Prerrequisitos verificados

- [ ] Etapas 1–11 cerradas: app funcionando, imagen firmada en etapa 5, cluster K8s con Argo CD + observabilidad.
- [ ] `kind` o cluster real accesible; `kubectl` apunta al contexto correcto.
- [ ] `helm` ≥ 3.14.
- [ ] `cosign` ≥ 2.2 (viene de la etapa 5, aquí sólo lo invocamos indirectamente vía Kyverno).
- [ ] Imagen de la app ya firmada en modo keyless desde un workflow GHA conocido (necesario para que `verify-images` tenga a quién creer).
- [ ] `conftest` y `opa` instalados localmente para iterar; en CI se descargan.
- [ ] Vault ya ejecutándose (modo `-dev` o PVC) con auth `kubernetes` habilitada y un KV v2 montado en `kv/`.
- [ ] `python3` + `PyYAML` para los chequeos sintácticos del `validate.sh`.

Si Vault no está disponible, el `starter/` de la actividad 1 trae un `docker run hashicorp/vault:1.17 server -dev` listo para arrancar.

---

## 4. Implementación guiada

### 4.1 ESO: `ClusterSecretStore` + `ExternalSecret`

Instalar el operador en su propio namespace:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set installCRDs=true
```

Aplicar el `ClusterSecretStore` (`security/eso/clustersecretstore.yaml`) que delega la autenticación a la `ServiceAccount` `external-secrets` vía Vault Kubernetes auth. **Por qué `ClusterSecretStore` y no `SecretStore`:** la app vive en varios namespaces (app, canary, preview); un store cluster-scoped evita duplicar la credencial.

Aplicar el `ExternalSecret` (`security/eso/externalsecret.yaml`); ESO crea el `Secret` nativo `capstone-app` y lo refresca cada 30 s. El `Deployment` de la app monta `capstone-app` como siempre, sin saber que vino de Vault.

**Política dura:** cero `kind: Secret` con `data:` en Git. Si Argo CD detecta uno, Kyverno (regla extra opcional) lo rechaza.

### 4.2 Kyverno: tres políticas

Instalar:

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace
helm upgrade --install kyverno-policies kyverno/kyverno-policies -n kyverno
```

Aplicar las tres `ClusterPolicy` en `security/kyverno/`:

1. `verify-images.yaml` — `verifyImages` con cosign **keyless**, confiando sólo en firmas producidas por el workflow `.github/workflows/release.yml` del repo capstone. `mutateDigest: true` ancla por digest, no por tag. Modo `Enforce`.
2. `required-labels.yaml` — todo `Pod`/`Deployment` debe traer `app.kubernetes.io/name`, `app.kubernetes.io/owner`, `app.kubernetes.io/env`. Rechazo en `Enforce` para `prod*`, `Audit` para `preview*`.
3. `baseline-restricted.yaml` — espejo "mínimo viable" del Pod Security Standard *restricted*: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `readOnlyRootFilesystem: true`, `seccompProfile.type: RuntimeDefault`. Rechazo `Enforce`.

**Por qué tres políticas separadas y no una gran policy:** cada una se puede deshabilitar/aflojar sin tocar las otras (p.ej. subir Enforce → Audit en un ambiente nuevo), y las tres se testean independiente con `kyverno test`.

Para iterar offline:

```bash
kyverno test security/kyverno/   # usa security/kyverno/tests/kyverno-test.yaml
```

### 4.3 Falco: regla custom

Instalar con el chart oficial y el driver `modern-bpf` (sin headers del kernel):

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm upgrade --install falco falcosecurity/falco -n falco --create-namespace \
  --set driver.kind=modern-bpf \
  --set tty=true \
  --set-file customRules."custom-rules\\.yaml"=security/falco/custom-rules.yaml
```

El archivo `security/falco/custom-rules.yaml` añade dos reglas: *shell interactivo dentro de contenedor de la app capstone* (alta señal: nunca pasa en caliente) y *proceso leyendo `/etc/shadow` desde cualquier pod* (siempre sospechoso). Prioridad `WARNING` para no ahogar el bus.

**Por qué sólo dos reglas y no 30:** las reglas por defecto de Falco ya cubren mucho; cada regla extra que tú escribes tienes que entenderla, afinarla, y defender sus FPs. Empieza chico.

### 4.4 Conftest en CI

Las políticas Rego viven bajo `security/conftest/policies/`:

- `required_labels.rego` — mismo contrato que la Kyverno `required-labels`, pero evaluado shift-left.
- `no_privileged.rego` — niega `securityContext.privileged: true` y hostPath mount.
- `pinned_images.rego` — niega imágenes con tag `latest` o sin digest cuando el namespace es `prod*`.

Para que el chequeo sea reproducible local y en CI:

```bash
# Local
conftest test k8s/base/ -p security/conftest/policies

# Unit tests de las propias reglas (offline)
opa test security/conftest/policies/ -v
```

El workflow `.github/workflows/policy-check.yml` descarga los binarios con *checksum pin*, corre `opa test` y luego `conftest test` sobre todos los `.yaml` bajo `projects/capstone/stages/*/k8s/` y `*/charts/`. Falla el PR si hay violación.

### 4.5 Flujo end-to-end de la etapa

1. Developer abre PR con un cambio al Deployment → `policy-check.yml` lo revisa (conftest) y lo aprueba/rechaza.
2. Merge a `main` → Argo CD sincroniza.
3. Antes de que el Pod se admita, Kyverno valida (3 políticas).
4. ESO materializa el `Secret` montado por el Pod.
5. Pod corre; Falco observa.

---

## 5. Actividades del estudiante

Viven bajo `activities/`. Cada una es ejecutable independiente, con su `validate.sh`.

| ID activity | Tipo | Tiempo | Objetivo |
|---|---|---|---|
| `cap-12-01-eso-vault-wiring` | guided-lab | 60 min | Cablear ESO → Vault con `ClusterSecretStore` + `ExternalSecret`, verificar sync. |
| `cap-12-02-kyverno-verify-signed-images` | independent | 75 min | Aplicar `verify-images` y demostrar que un Deployment con imagen no firmada se rechaza; dejar `kyverno test` verde. |
| `cap-12-03-conftest-policy-as-code-ci` | debug | 50 min | Reparar un `policy-check.yml` roto y las Rego defectuosas hasta que el pipeline falle con el manifiesto malo y pase con el bueno. |

Se cumple la regla "al menos una `independent` o `debug`" con 2 y 3.

---

## 6. Entregables

1. `security/eso/{clustersecretstore,externalsecret}.yaml` aplicables y sincronizando desde Vault.
2. `security/kyverno/*.yaml` + `security/kyverno/tests/kyverno-test.yaml` pasando con `kyverno test`.
3. `security/falco/custom-rules.yaml` desplegado como `customRules` en el Helm release de Falco.
4. `security/conftest/policies/*.rego` con `opa test` verde y `conftest test` verde contra manifiestos buenos.
5. `.github/workflows/policy-check.yml` corriendo en todo PR.
6. Las 3 actividades con `tests/validate.sh` en 0.

---

## 7. Pruebas y criterios de aceptación

Chequeos automáticos:

- [ ] `python3 -c 'import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]' security/**/*.yaml` → 0.
- [ ] `kyverno test security/kyverno/` → PASS (offline, sin cluster).
- [ ] `opa test security/conftest/policies/ -v` → PASS (offline).
- [ ] `conftest test security/conftest/tests/fixtures/good.yaml -p security/conftest/policies` → 0 violaciones.
- [ ] `conftest test security/conftest/tests/fixtures/bad.yaml -p security/conftest/policies` → ≥ 1 violación.
- [ ] En cluster: `kubectl apply -f` de un Pod `privileged: true` → rechazado.
- [ ] En cluster: `kubectl get externalsecret -A` reporta `SecretSyncedError=False`.
- [ ] En cluster: `kubectl -n falco logs ds/falco | grep "Shell spawned in capstone"` tras `kubectl exec` en el pod.

Criterios de calidad:

- [ ] Ningún `kind: Secret` con `data:` versionado en Git.
- [ ] Ninguna imagen con `:latest`.
- [ ] Toda `ClusterPolicy` tiene `validationFailureAction: Enforce` en namespaces `prod*`.
- [ ] `policy-check.yml` bloquea el merge (branch protection + required status check).

---

## 8. Costos y limpieza

**Costo cloud.** $0 si corre en `kind`. En EKS/GKE/AKS el coste se hereda de la etapa 8; ESO/Kyverno/Falco añaden ~150 MiB RAM por nodo y ninguna instancia nueva.

**Limpieza:**

```bash
helm uninstall falco -n falco
helm uninstall kyverno-policies kyverno -n kyverno
helm uninstall external-secrets -n external-secrets
kubectl delete ns falco kyverno external-secrets --ignore-not-found
docker rm -f capstone-vault-dev 2>/dev/null || true
rm -rf /tmp/cap-12-*
```

Guard-rails: si Falco empieza a inundar logs, bajar prioridad de las reglas custom a `NOTICE` antes de borrarlas; nunca dejar `priority: DEBUG` en producción.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| `verify-images` bloquea TODO el cluster porque la firma del vendor-image no está. | Usar `imageReferences` acotado al registry del capstone; dejar los `kube-system` fuera. |
| ESO no se autentica contra Vault porque la `ServiceAccount` no tiene el `role` creado. | `activities/01` incluye `vault write auth/kubernetes/role/eso-capstone ...` en el starter. |
| Falco en Mac/arm64 falla con `modern-bpf`. | Fallback a driver `ebpf` clásico o correr Falco sólo en la VM `kind` Linux. |

**Hints progresivos** (ordenados):

1. ¿`kyverno test` falla? Revisa que `apiVersion` sea `kyverno.io/v1` y que el `kind` del recurso bajo test exista.
2. ¿ESO reporta `InvalidProviderConfig`? `kubectl -n external-secrets logs deploy/external-secrets` suele señalar el campo exacto.
3. ¿`conftest test` pasa en local pero falla en CI? Compara versiones; usa `--instance-trace` para ver qué regla disparó.

---

## 10. Puente con la siguiente etapa

**Qué habilita.** La etapa 13 (Platform Engineering con Backstage + scorecards + DORA) necesita señales: Kyverno emite eventos, Falco emite alerts, ESO emite status, y el workflow de CI emite checks. Todo eso alimenta el *scorecard de seguridad* del catálogo Backstage.

**Qué dejamos corriendo.** ESO, Kyverno y Falco permanentes en el cluster. El workflow `policy-check` queda registrado como required check en `main`.

**Cliffhanger.** Tenemos tres capas de seguridad activas y señales dispersas (logs Kyverno, eventos Falco, status ESO, checks CI). ¿Cómo le decimos a un developer nuevo, en 10 segundos, si *su* servicio cumple con todo esto? La etapa 13 ensambla el scorecard que responde esa pregunta.

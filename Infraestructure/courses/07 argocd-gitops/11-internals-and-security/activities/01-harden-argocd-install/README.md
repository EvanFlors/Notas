# Actividad 01 — Endurecer una instalación default de Argo CD

## 1. Identificación

- **ID:** `argo-11-01-harden-argocd-install`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `11-internals-and-security`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Partes de una instalación de Argo CD *default* (como la que haces en `argo-02`) y aplicas **7 controles** de hardening que el validador comprueba. Es el checklist mínimo que una auditoría razonable exigiría antes de dar luz verde a prod.

El `bootstrap.sh` instala Argo CD en un cluster kind limpio (si no tienes uno con Argo CD, lo levanta por ti). Tu trabajo son los 7 cambios.

## 3. Objetivos (= checks del validador)

1. **Admin local deshabilitado**: `argocd-cm` `data.admin.enabled: "false"`.
2. **HTTPS obligatorio**: `argocd-cmd-params-cm` `server.insecure: "false"` **o** flag `--insecure` ausente del Deployment `argocd-server`.
3. **PSA `restricted`** en namespace `argocd`: label `pod-security.kubernetes.io/enforce=restricted`.
4. **NetworkPolicy** default-deny en `argocd` con regla egress a `kube-dns`.
5. **`server.secretkey` rotada**: el valor actual difiere del instalado por el chart (hash SHA256 distinto del "default" conocido, o `argocd-secret` modificado tras el bootstrap).
6. **Policy CSV deny-by-default**: `argocd-rbac-cm` tiene `policy.default: ""` **y** al menos una línea `p, role:...` **y** al menos una `g, ..., role:...`.
7. **No `cluster-admin` crudo** al SA `argocd-application-controller`: no debe existir `ClusterRoleBinding` que ate directamente ese SA a `ClusterRole/cluster-admin`.

## 4. Prerrequisitos

- `kind`, `kubectl`, `helm` (opcional) instalados.
- `jq` disponible (lo usa `validate.sh`).
- Si no tienes Argo CD en el cluster, el bootstrap lo instala con el manifiesto estable (`install.yaml`).
- Sin red externa salvo pulls iniciales. **Costo**: $0.

## 5. Instrucciones

### 5.1 Bootstrap

```bash
bash courses/argocd-gitops/11-internals-and-security/activities/01-harden-argocd-install/starter/bootstrap.sh /tmp/argo-11-01
cd /tmp/argo-11-01/work
```

El bootstrap:

- Verifica que haya un cluster activo (si no, te sugiere `kind create cluster --name argo-11-01`).
- Crea el namespace `argocd` **sin** labels PSA.
- Aplica el `install.yaml` oficial estable de Argo CD.
- Espera a que `argocd-server` esté Ready.
- Deja en `./work/`:
  - `argocd-cm.yaml` — placeholder con admin **habilitado**. Edítalo.
  - `argocd-cmd-params-cm.yaml` — placeholder con `server.insecure: "true"`. Edítalo.
  - `argocd-rbac-cm.yaml` — placeholder permisivo. Reescríbelo deny-by-default.
  - `namespace-labels.sh` — script para que escribas tú los labels PSA.
  - `networkpolicy.yaml` — placeholder vacío. Escribe la default-deny + egress DNS.
  - `rotate-secretkey.sh` — comando pre-escrito para rotar `server.secretkey`.

### 5.2 Trabajo

Para cada control, el patrón es: edita el YAML, `kubectl apply`, verifica con `kubectl get -o yaml`. Lee `theory/lesson.md` §4, §5, §9, §10 para la base conceptual.

Pistas:

- **Control 3 (PSA)**: tres labels (`enforce`, `audit`, `warn`) = `restricted`. Si algún pod del propio Argo CD rompe, abre el issue en vez de rebajar.
- **Control 4 (NP)**: dos manifests — un `default-deny` sobre `podSelector: {}` + una NP específica permitiendo egress UDP/53 al ns `kube-system` (o label `kubernetes.io/metadata.name: kube-system`). Opcionalmente añade reglas para Git y el apiserver.
- **Control 5 (rotación)**: borra la key `server.secretkey` de `argocd-secret` → Argo CD regenera una nueva al reiniciarse (`kubectl -n argocd rollout restart deploy/argocd-server`).
- **Control 6 (RBAC)**: usa el CSV del Ejemplo 02 como base. El validador exige mínimo un `p` y un `g`.
- **Control 7 (cluster-admin)**: busca con `kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin")'`. Si Argo CD está atado directamente, cámbialo por un ClusterRole propio con permisos más acotados **o** justifica en un comentario. El validador no exige verificar funcionalidad post-cambio — solo que el binding directo a `cluster-admin` no esté.

### 5.3 Validar

```bash
bash courses/argocd-gitops/11-internals-and-security/activities/01-harden-argocd-install/tests/validate.sh
```

Debe terminar en `RESULT: 7/7 controles OK`.

## 6. Resultado esperado

- `kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.admin\.enabled}'` → `false`.
- `kubectl -n argocd get cm argocd-cmd-params-cm -o jsonpath='{.data.server\.insecure}'` → `false`.
- `kubectl get ns argocd -L pod-security.kubernetes.io/enforce` → `restricted`.
- `kubectl -n argocd get networkpolicy` → al menos `default-deny` + regla DNS.
- `argocd-secret.data.server\.secretkey` existe pero el hash es distinto al del bootstrap.
- `argocd-rbac-cm.data.policy\.csv` incluye `p, role:...` y `g, ..., role:...`; `policy.default` vacío.
- `kubectl get clusterrolebindings -o json | jq ...` **no** devuelve binding directo del SA del controller a `cluster-admin`.

## 7. Criterios de aceptación

- **Seguridad**: todos los controles presentes y verificados por `validate.sh`.
- **Funcionalidad**: Argo CD sigue operacional — pods Running, `kubectl -n argocd get pods` todos Ready.
- **Reproducibilidad**: `bootstrap.sh` corre dos veces sin dejar basura (`rm -rf /tmp/argo-11-01` al re-ejecutarse). `validate.sh` idempotente.

## 8. Validación

Automatizada: `bash tests/validate.sh`. Prueba los 7 controles con `kubectl` + `jq`.

## 9. Preguntas de reflexión

- Deshabilitaste `admin.enabled`. ¿Qué pasa si tu IdP OIDC se cae? ¿Cómo haces break-glass?
- La rotación de `server.secretkey` invalida JWTs vigentes. ¿Qué romperías en un pipeline que llama al API de Argo CD con un token project-level? ¿Cómo lo coordinas?
- `cluster-admin` para el `application-controller` es "cómodo". ¿Qué permisos *mínimos* le darías para que gestione un namespace específico? (Pista: `Role` + `RoleBinding` namespace-scoped + registrar el cluster con `namespaces:` acotado.)
- Aplicaste PSA `restricted` al ns `argocd`. ¿Qué cambios tendrías que hacer si alguno de los pods del propio Argo CD *no* cumpliera? ¿Downgrade a `baseline` o patch del chart?
- Tu NetworkPolicy default-deny bloquea egress. Argo CD necesita salir a Git y al apiserver — ¿cómo verificas que no has roto repo-server?

## 10. Extensiones

- Añade una regla NetworkPolicy explícita para `argocd-repo-server` → GitHub (DNS egress + 443 externo).
- Mide el impacto de PSA `restricted` sobre el `pod-security.kubernetes.io/warn-version=latest` corriendo `kubectl -n argocd describe pod` y buscando warnings.
- Integra la OAuth App del Ejemplo 01 y verifica login OIDC real.
- Convierte todos los manifests editados en un `kustomize overlay` + commitea a un repo + haz que Argo CD se gestione a sí mismo con ese overlay.

## 11. Limpieza

```bash
# Si solo quieres deshacer la actividad:
rm -rf /tmp/argo-11-01
# Si creaste cluster para esto:
# kind delete cluster --name argo-11-01
```

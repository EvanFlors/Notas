# Teoría — Operadores y CRDs

> 12 secciones. Prosa en español, código en inglés.

## 1. El API de Kubernetes es extensible por diseño

Kubernetes no es "un orquestador con una lista fija de recursos". Es un **API server con un modelo uniforme** (`spec` + `status`, resource groups versionados, admission chain, controllers) y mecanismos oficiales para añadir **tipos nuevos** sin tocar el core:

- **CustomResourceDefinition (CRD)** — recursos nuevos almacenados en etcd y servidos por el apiserver.
- **API aggregation** (`APIService`) — un apiserver auxiliar atiende un grupo (lo usan `metrics-server`, `kube-state-metrics` indirectamente, y proyectos como `apiserver-builder`). Más poderoso pero mucho más caro de operar; en 99 % de casos un CRD basta.

Una vez existe el tipo, falta un **controller** que lo "haga pasar algo". Un CRD sin controller es solo almacenamiento tipado en etcd — útil para pruebas, pero no cambia el mundo.

**Operator pattern** = **CRD(s)** + **controller(s)** + **conocimiento específico de dominio** empaquetado como código.

## 2. CRD: anatomía mínima

Una CRD declara nombre, grupo, versiones, scope y schema (OpenAPI v3):

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: echoes.demo.academy.io
spec:
  group: demo.academy.io
  names:
    plural: echoes
    singular: echo
    kind: Echo
    shortNames: [ec]
    categories: [all]
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          required: [spec]
          properties:
            spec:
              type: object
              required: [message]
              properties:
                message:
                  type: string
                  minLength: 1
                  maxLength: 256
            status:
              type: object
              properties:
                observedMessage: { type: string }
                lastReconciledAt: { type: string, format: date-time }
      subresources:
        status: {}
      additionalPrinterColumns:
        - name: Message
          type: string
          jsonPath: .spec.message
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
```

Notas:
- `scope: Namespaced` para la mayoría de workloads; `Cluster` para cosas globales (ClusterIssuer, Namespace-like).
- `subresources.status: {}` **habilita** el endpoint `/status`. Sin él, actualizar `status` cuenta como escritura al objeto completo y pelea con `spec`.
- `additionalPrinterColumns` mejoran `kubectl get` sin obligar a `-o yaml`.
- El schema OpenAPI es **validación en apiserver**, no una sugerencia: evita basura en etcd.

## 3. Versionado: `v1alpha1 → v1beta1 → v1` y conversion

Convención Kubernetes (y de facto en el ecosistema):

- `v1alpha1`: puede desaparecer sin aviso, puede cambiar entre releases.
- `v1beta1`: razonablemente estable, se suele avisar la deprecación.
- `v1`: estable, compatibilidad hacia atrás.

Una CRD puede **servir varias versiones a la vez**. En `spec.versions[]`:
- `served: true` → el apiserver atiende GET/LIST/WATCH en esa versión.
- `storage: true` → **una sola** versión es la "canónica" en etcd; las demás se convierten al leer/escribir.

Convertir entre versiones de un objeto:
- **Sin webhook** → solo si los esquemas son compatibles (los campos coinciden).
- **Conversion webhook** → un servicio HTTPS que recibe `ConversionReview` y devuelve el objeto en la versión pedida. Necesario cuando el schema cambia (campos renombrados, descompuestos, con defaults nuevos).

Regla de oro: una CRD **nunca** debería romper a sus consumidores. Si tienes que romper, suma una versión nueva, mantén la vieja served por *N* releases, y publica un conversion webhook.

## 4. El operator pattern

Idea: **codificar en software el conocimiento operativo** de un sistema (una DB, un bus de mensajes, un sistema de PKI) y exponerlo como recursos declarativos.

Ejemplo CloudNativePG (CNPG): un `Cluster` CR expresa "quiero Postgres HA con 3 instancias, backups a S3, failover automático". El operador se encarga de:
- crear StatefulSet, Services, PodDisruptionBudget, PVCs,
- elegir primary y promover secundarios,
- orquestar `pg_basebackup`, WAL archiving,
- rotar passwords, generar certs,
- aplicar upgrades minor,
- publicar `status` con el estado real del cluster.

Sin operador, todo eso sería runbooks en Confluence. Con operador, es *código*, versionado, revisado, y auditable.

**Lo que NO debe hacer un operador**:
- Ser un bash wrapper gigante en `exec` dentro del contenedor.
- Esconder decisiones de DBA/SRE críticas (restore de un backup corrupto, por ejemplo).
- Depender de "fuentes de verdad" externas al cluster que nadie sabe quién mantiene.

## 5. Controller = reconciliation loop

Un controller observa un tipo (CR o nativo) y ejecuta un `Reconcile(req)` cada vez que algo cambia (watch) o periódicamente (resync). El esqueleto en `controller-runtime` (Go):

```go
func (r *EchoReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    var echo demov1alpha1.Echo
    if err := r.Get(ctx, req.NamespacedName, &echo); err != nil {
        // NotFound → el CR fue borrado; GC se encarga de los hijos por ownerRef.
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    desired := buildConfigMap(&echo)
    if err := ctrl.SetControllerReference(&echo, desired, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }

    var existing corev1.ConfigMap
    err := r.Get(ctx, client.ObjectKeyFromObject(desired), &existing)
    switch {
    case apierrors.IsNotFound(err):
        if err := r.Create(ctx, desired); err != nil {
            return ctrl.Result{}, err
        }
    case err != nil:
        return ctrl.Result{}, err
    default:
        if existing.Data["message"] != desired.Data["message"] {
            existing.Data = desired.Data
            if err := r.Update(ctx, &existing); err != nil {
                return ctrl.Result{}, err
            }
        }
    }

    // Status update is a separate call to the /status subresource.
    echo.Status.ObservedMessage = echo.Spec.Message
    echo.Status.LastReconciledAt = metav1.Now()
    if err := r.Status().Update(ctx, &echo); err != nil {
        return ctrl.Result{}, err
    }

    log.Info("reconciled", "echo", req.NamespacedName)
    return ctrl.Result{}, nil
}
```

Propiedades no negociables:
- **Idempotente**: ejecutar `Reconcile` N veces debe ser equivalente a ejecutarlo una.
- **Nivel-triggered** (observa estado, no eventos únicos): si pierdes un evento, la próxima vuelta corrige.
- **Rápido en el camino feliz**: `Reconcile` se llama *mucho*.
- **No bloquea**: trabajos largos → status "Progressing", requeue, workers aparte.

## 6. Sub-resource `/status`

Separar `spec` (lo que pide el usuario) y `status` (lo que el controller observa) resuelve dos problemas:

1. **Conflictos de escritura**: usuario escribe `spec`, controller escribe `status`. Si fueran el mismo endpoint, cada `Update()` del controller podría pisar un `spec` recién editado. Con `/status` ambos pueden actualizar en paralelo (optimistic concurrency con `resourceVersion`).
2. **RBAC fino**: puedes dar `update` en `echoes/status` al controller y `update` en `echoes` al usuario, sin que ninguno pueda tocar la parte del otro.

Habilitarlo en la CRD requiere **ambas cosas**: `subresources.status: {}` + el controller usa `.Status().Update()` (en controller-runtime) o `UpdateStatus()` en los clients tipados. Si el controller llama `Update()` sobre el objeto completo, el apiserver **descarta** los cambios de status silenciosamente.

## 7. Frameworks

| Framework | Lenguaje | Nivel | Cuándo elegirlo |
|---|---|---|---|
| **controller-runtime** | Go | librería base | Si ya sabes Go y quieres control fino; es lo que usan los demás por debajo. |
| **Kubebuilder** | Go | scaffolding sobre controller-runtime | Default pragmático para operadores Go: `kubebuilder init && kubebuilder create api` y tienes CRD + controller + Makefile + envtest. |
| **Operator SDK** | Go / Ansible / Helm | superset de Kubebuilder + plugins | Si vienes del ecosistema OperatorHub (Red Hat), o quieres el modo "Helm operator" / "Ansible operator" sin escribir Go. |
| **Metacontroller** | cualquiera (webhooks) | mete el loop fuera, llama a tu webhook | Prototipos rápidos en Python/Node; no para operadores "serios". |
| **KubeOps / kopf / Shoot** | C# / Python / … | wrappers no-Go | Nicho; útiles si tu organización ya es .NET o Python-only. |

Recomendación por defecto: **Kubebuilder** para proyectos nuevos en Go; **Operator SDK Helm/Ansible** si lo tuyo es empaquetar un chart ya existente con un poco de lógica.

## 8. Testing con `envtest`

`controller-runtime`/`envtest` arranca binarios reales de **`kube-apiserver`** y **`etcd`** (sin kubelet) en el host del test. Puedes:
- aplicar tu CRD,
- crear CRs,
- disparar el `Reconcile`,
- afirmar que se crean los recursos esperados.

Ventaja: pruebas reales de reconciliación en segundos, sin cluster, sin kind. Limitación: **no hay Pods de verdad** — el scheduler y el kubelet no corren. Para probar que un Deployment produce Pods vivos necesitas un cluster de integración (kind) además.

Patrón habitual:
- **Unit tests** del `Reconcile` con `fake client` de `sigs.k8s.io/controller-runtime/pkg/client/fake` → rápido, sin apiserver.
- **Integration tests** con `envtest` → prueba la cadena completa CR → recursos.
- **E2E tests** con kind + Ginkgo → prueba que las Pods arranquen y hagan algo.

## 9. Diseño de API: lo que separa un CRD serio de uno de juguete

1. **Nombra el dominio, no la implementación**. `PostgresCluster`, no `PostgresStatefulSet`.
2. **Usa condiciones** (`Ready`, `Available`, `Degraded`) en `status.conditions` con el schema estándar `metav1.Condition`.
3. **Printer columns** útiles (`kubectl get` debe ser legible).
4. **Short names** y **categories** (`kubectl get all` debería incluir, o no, tus CRs según decidas).
5. **Validación en el schema**, no en el controller cuando se pueda (regex, enums, min/max).
6. **Immutable fields** vía webhook validating (p. ej. `storageClassName`).
7. **Defaults** vía webhook mutating (si no te alcanza con los defaults del schema).
8. **Versiona desde el día 1** con `v1alpha1` explícito; no publiques `v1` prematuro.

## 10. Operadores famosos (ecosistema vivo)

- **Postgres**:
  - **CloudNativePG (CNPG)** — moderno, cloud-native, backups a object storage, operator-driven failover, HA bien integrado. Ganando tracción fuerte.
  - **Zalando postgres-operator** — maduro, usado en producción grande (Zalando mismo), apoyado por Patroni, flexibilidad alta, curva de aprendizaje mayor.
  - **Crunchy PGO** — enterprise focus, muy completo, licencia Apache 2.0.
- **Kafka**: **Strimzi** — estándar de facto en el ecosistema CNCF para Kafka en K8s. Maneja brokers, topics, users, mirror-maker, cruise-control.
- **cert-manager** — PKI del cluster: `Issuer`/`ClusterIssuer` (ACME, Vault, CA interna), `Certificate` crea Secrets TLS con rotación automática. Casi obligatorio en clusters con Ingress TLS.
- **external-secrets** — sincroniza `ExternalSecret` → `Secret` K8s desde Vault, AWS Secrets Manager, GCP Secret Manager, 1Password, etc. Reemplaza "exportar secretos a kubectl apply a mano".
- **Argo CD / Argo Workflows / Argo Rollouts / Argo Events** — GitOps (CD), DAGs de jobs, progressive delivery, event bus. Son operadores en el sentido estricto: sus `Application`, `Workflow`, `Rollout`, `Sensor` son CRs.
- **Prometheus Operator** — `ServiceMonitor`, `PodMonitor`, `PrometheusRule`, `Alertmanager` convierten configuración de monitoring en objetos declarativos.
- **Istio / Linkerd** — service meshes modernos son operadores: sus `VirtualService`, `AuthorizationPolicy`, `ServiceProfile` son CRs.

Patrón común: cada uno define *su* dominio como objetos K8s y vive del *reconciliation loop*.

## 11. Criterios para adoptar (o rechazar) un operador de terceros

Antes de meter un operador en producción:

1. **Madurez del proyecto**: versión, release cadence, issues/PRs abiertos vs cerrados, mantenedores identificables, respaldo de fundación (CNCF Graduated/Incubating es señal fuerte).
2. **Licencia**: Apache 2.0, MIT son seguras. Business Source License (BSL), SSPL, dual-licensing agresivo requieren leer legal.
3. **Blast radius**: ¿qué permisos pide? Un operador con `cluster-admin` que corre en `kube-system` es un *compromise single point*. Prefiere RBAC acotado por namespace.
4. **Backup & restore**: ¿cómo recuperas el estado? Si borras el operador por error, ¿se van los recursos gestionados? ¿Los CR tienen finalizers razonables?
5. **Upgrade story**: ¿cómo se migra entre versiones? ¿Hay conversion webhooks? ¿Cuántas versiones *N-1*, *N-2* se soportan?
6. **Observabilidad**: ¿expone métricas Prometheus? ¿Emite Kubernetes Events útiles? ¿Logs estructurados?
7. **Documentación**: operacional, no solo "install". Incluye troubleshooting, runbooks, fallos conocidos.
8. **Comunidad**: Slack/Discord activo, canal de seguridad, política de disclosure.
9. **Alternativas evaluadas**: ¿qué otros proyectos resuelven lo mismo? ¿Por qué este? Un ADR corto evita arrepentimientos.
10. **Lock-in**: ¿puedes migrar fuera? Para operadores de DB es crítico: los datos deben poder salir con `pg_dump`, `mongodump`, etc., no quedar atrapados en formato propietario.

Red flags:
- "El operador reinstala todo si lo borras" → probablemente sin finalizers o con lógica frágil.
- Un solo mantenedor, repo con último commit hace 18 meses.
- Documentación de referencia es un README con ejemplos "hello world" y nada más.
- Pide `hostPath`, `hostNetwork`, `privileged: true` sin explicar por qué.

## 12. Qué construirás en este módulo

- **Ejemplo 01**: una CRD mínima `Echo` y el esqueleto de su controller.
- **Ejemplo 02**: walkthrough de **cert-manager** (instalación, `ClusterIssuer`, `Certificate`).
- **Ejemplo 03**: walkthrough de **CloudNativePG** como caso de operador maduro de referencia.
- **Actividad 01**: implementar el `Reconcile` del operador `Echo` con Kubebuilder (o, sin toolchain Go, documentar CRD + pseudocódigo).
- **Actividad 02**: evaluar **CloudNativePG vs Zalando postgres-operator** con criterios explícitos.

Cerramos con la pregunta que debe quedar grabada: *¿este operador reduce la carga operativa en el 95 % de los casos y degrada con gracia en el 5 % restante? Si no, no lo adoptes.*

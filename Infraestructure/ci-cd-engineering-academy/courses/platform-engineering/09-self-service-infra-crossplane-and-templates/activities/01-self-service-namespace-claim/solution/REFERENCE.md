# solution/REFERENCE.md — plat-09-01

Referencia para autoevaluarte. **No** la mires antes de intentar la actividad.

## Valores esperados

- `claim.yaml`:
  - `metadata.name: student-claim`
  - `metadata.namespace: team-student`
  - `spec.parameters.name: student-ns`
  - `spec.parameters.tier: small` (o cualquiera de `[small, medium, large]`; `small` es el caso probado por el validador para los valores de quota)
  - `spec.parameters.env: dev`

- `xrd.yaml`:
  - `pattern: '^[a-z][a-z0-9-]{2,30}$'`
  - `enum: [small, medium, large]`

- `composition.yaml`:
  - Patch que mapea `spec.parameters.tier` → `spec.forProvider.manifest.spec.hard["requests.cpu"]` con transform `type: map` `{ small: "2", medium: "8", large: "32" }`.
  - Patch que mapea `spec.parameters.tier` → `spec.forProvider.manifest.spec.hard["requests.memory"]` con transform `type: map` `{ small: "4Gi", medium: "16Gi", large: "64Gi" }`.

Ver `examples/02-xrd-namespace-product/composition.yaml` para la forma exacta de los patches.

## Qué debería materializar

- `kubectl get xrd xnamespaceproducts.platform.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}'` → `True`.
- `kubectl get composition xnamespaceproducts.k8s-native` → OK.
- `kubectl -n team-student get namespaceproductclaim student-claim -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'` → `True`.
- `kubectl get ns student-ns -o jsonpath='{.metadata.labels.managed-by}'` → `crossplane`.
- `kubectl -n student-ns get resourcequota student-ns-quota -o jsonpath='{.spec.hard.requests\.cpu}'` → `2` (si `tier=small`).
- `kubectl -n student-ns get networkpolicy student-ns-deny-all -o jsonpath='{.spec.policyTypes}'` → `["Ingress","Egress"]`.

## Preguntas de reflexión (respuestas sintéticas)

1. **¿Por qué el claim en `team-student`?** Porque el RBAC del developer es por namespace. En `crossplane-system` el developer **no** debería tener permisos; crear claims ahí sería saltarse el modelo.
2. **¿Quién garantiza que el developer no cree el `Namespace` directamente?** Lo garantiza el **RBAC del cluster**: a los developers no se les da verbo `create` sobre `namespaces`. Sí se les da `create` sobre `namespaceproductclaims.platform.io` en su namespace. Crossplane es el intermediario; el guardia es RBAC.
3. **¿Borrar el claim borra el namespace?** Por default sí (`deletionPolicy: Delete`). Con `deletionPolicy: Orphan` en los MRs, el namespace sobrevive al borrado del claim — útil para migraciones, peligroso si se olvida.
4. **Versionar a `v1beta1`:** añadir `v1beta1` a `spec.versions` con `storage: true` (y `v1alpha1` sirviendo con `served: true`); escribir un conversion webhook o usar conversion por anotaciones si el cambio de schema es compatible. Los claims `v1alpha1` siguen funcionando.
5. **Cambiar a `provider-aws`:** (a) sustituyes los `Object` MRs por `s3.aws.upbound.io/Bucket` (o lo que aplique); (b) necesitas un `ProviderConfig` con credenciales (secret o IRSA/Workload Identity). El claim del developer **no cambia**.

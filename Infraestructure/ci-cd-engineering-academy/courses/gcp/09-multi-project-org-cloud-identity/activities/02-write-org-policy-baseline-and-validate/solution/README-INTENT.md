# REFERENCE — Baseline de Org Policies y VPC-SC perimeter (intent)

> Documento de intención: qué declara cada archivo, dónde se adjunta y por qué. Los YAMLs están en archivos adyacentes.

## Resumen

Cuatro Org Policies forman el **baseline** del tenant: toda la organización hereda estos guardrails declarativos. Un perímetro VPC-SC envuelve los projects productivos regulados.

| Archivo | Adjunta a | Protege |
|---------|-----------|---------|
| `org-policy-disable-sa-key-creation` | Organization (override `enforce=false` en Sandbox). | Prohíbe descargar SA keys; obliga a impersonation o WIF. |
| `org-policy-vm-external-ip` | Organization. | Obliga a usar Cloud NAT para salida y LB para entrada. |
| `org-policy-storage-public-access-prevention` | Organization. | Cero buckets abiertos al mundo. |
| `org-policy-allowed-member-domains` | Organization. | Ningún principal fuera del dominio corporativo. |
| `vpc-sc-perimeter` | Access Policy a nivel Organization. | Evita exfiltración de datos regulados vía APIs de Google. |

---

## org-policy-disable-sa-key-creation

### Qué declara

El constraint boolean `iam.disableServiceAccountKeyCreation` queda `enforce: true` para toda la organización. Como consecuencia, `gcloud iam service-accounts keys create` devuelve `PERMISSION_DENIED` en cualquier project de la jerarquía.

### Dónde se adjunta

A **Organization**. Se hereda por defecto a todos los folders y projects. En el folder `Sandbox` se adjunta una policy local con `enforce: false` + `inheritFromParent: false` para permitir experimentación controlada con SA keys efímeras (nunca productivas).

### Excepciones

Solo `Sandbox`. Si en el futuro un workload necesita SA keys (p. ej. una integración legacy con un sistema on-prem que no entiende OIDC), se abrirá un ticket y se evaluará; preferible usar WIF antes que relajar la policy.

---

## org-policy-vm-external-ip

### Qué declara

El constraint `compute.vmExternalIpAccess` queda con `denyAll: true`: ninguna VM en la jerarquía puede tener IP externa asignada en una NIC.

### Dónde se adjunta

A **Organization**. Toda VM creada en cualquier project heredará el deny y fallará con `googleapi: Error 412: constraint ...`.

### Excepciones

Si aparece un bastion host o un NAT dedicado, se crea un project específico (p. ej. `bastion-prod`) con una policy local `inheritFromParent: false` + `allowedValues` listando únicamente los self-links de las VMs permitidas. Nunca abrir el deny en Organization.

Para salida a internet, obligatorio **Cloud NAT**. Para entrada, obligatorio **Load Balancer**.

---

## org-policy-storage-public-access-prevention

### Qué declara

El constraint boolean `storage.publicAccessPrevention` queda `enforce: true`: ningún bucket GCS puede ser público. Cualquier `gsutil iam ch allUsers:objectViewer gs://bucket` falla con `PRECONDITION_FAILED`.

### Dónde se adjunta

A **Organization**. Afecta a todos los buckets creados en cualquier project. Las clases de policies de bucket que violen el constraint también son rechazadas.

### Excepciones

Ninguna. Si alguien necesita servir contenido público (p. ej. un sitio estático), se hace vía **Cloud CDN + Load Balancer HTTPS** sirviendo desde un bucket privado con `backend bucket signed URL`, no exponiendo el bucket.

---

## org-policy-allowed-member-domains

### Qué declara

El constraint list `iam.allowedPolicyMemberDomains` restringe los principales permitidos en bindings IAM al **customer ID** del dominio corporativo (en el YAML: placeholder `C01abc234`). Añadir `attacker@gmail.com` como owner de un project falla con `googleapi: Error 412`.

### Dónde se adjunta

A **Organization**. El customer ID real se obtiene con `gcloud organizations list --format="value(owner.directoryCustomerId)"`. No se puede dejar el YAML con placeholder — Fase 4 sustituirá por el real al aplicar.

### Excepciones

Ninguna por diseño. Si se necesita invitar a un externo (consultor, auditor), se le crea una identidad **dentro** de Cloud Identity bajo un subdominio corporativo (`contractor@contratistas.ejemplo.com`), no se abre el constraint.

Si no se restringe este constraint, cualquier owner de project puede añadir `attacker@gmail.com` como `roles/owner` y la organización pierde el perímetro de identidad en una sola llamada API.

---

## vpc-sc-perimeter

### Qué declara

Un **service perimeter** llamado `prod_data_perimeter` que envuelve los projects `checkout-prod` y `analytics-prod` (números de project como placeholders — Fase 4 los sustituye). Dentro del perímetro:

- `restrictedServices` = `storage`, `bigquery`, `cloudkms`, `secretmanager`.
- `accessLevels` = `corp_network` (un access level definido en Access Context Manager que valida la IP de origen).
- `vpcAccessibleServices.enableRestriction: true` + `allowedServices: RESTRICTED-SERVICES` — las VMs dentro del perímetro solo pueden llamar a los mismos servicios restringidos vía Private Google Access.
- `ingressPolicies` / `egressPolicies` vacíos: ningún tráfico cruzado por ahora.

### Dónde se adjunta

A la **Access Policy** de la Organization (único singleton por org en el plano VPC-SC). El ID real se obtiene con `gcloud access-context-manager policies list --organization=<ORG>`.

### Dry-run mode primero

**Obligatorio** adoptar en dry-run (`spec` en vez de `status`, con `useExplicitDryRunSpec: true`) durante **al menos 2 semanas**. Durante ese tiempo:

- Las violaciones se **registran** en Cloud Logging (log name `vpcservicecontrols`) pero **no bloquean**.
- Se revisan los logs para identificar llamadas legítimas que romperían: runners CI accediendo a buckets, developers con `gcloud` desde fuera de la red corporativa, Terraform state fuera del perímetro, etc.
- Se ajustan `ingressPolicies` o `accessLevels` según lo observado.

Después del dry-run, se promueve a `status` (enforce) con los ajustes incorporados.

### Access Context Manager

El access level `corp_network` se define en **Access Context Manager** y combina:

- Rango IP corporativo (VPN de la empresa, oficinas).
- (Fase 2) Device trust vía Chrome Enterprise / BeyondCorp.
- Verified Access via certificados corporativos.

Sin Access Context Manager no se puede diseñar un perímetro VPC-SC útil: el perímetro necesita una definición de "quién sí puede entrar", no solo "quién no".

### Qué NO entra

- Projects `*-dev` y `*-stg`: no están en el perímetro para no complicar CI/CD; los datos de dev son sintéticos.
- `tools-shared`: fuera del perímetro para que los runners CI puedan hacer pull de Artifact Registry y leer Terraform state. Si en el futuro los runners deben entrar al perímetro para hacer `terraform apply` en `checkout-prod`, se añaden como `ingressPolicies` con `identityType: ANY_SERVICE_ACCOUNT` apuntando al SA del runner.

---

## Preguntas abiertas (fase 2)

- Promover el perímetro de dry-run a enforce tras validación.
- Añadir un segundo perímetro `security_perimeter` alrededor de `logging-prod` y `security-audit`.
- Introducir custom constraints con CEL para `require-label-cost-center` sobre Compute Instances y Cloud Run services.

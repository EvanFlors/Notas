# ADR — Sugerencia de referencia (no es "la" respuesta)

> Esta solución existe para contrastar *después* de que entregaste la tuya. Hay otras
> opciones válidas.

## Org A — StartupTech → **Control-plane cluster** (hub-and-spoke modesto)

- 3 clusters homogéneos, mismo cloud, mismo equipo plat. chico → la ganancia de "una sola
  UI, un solo backup, un solo RBAC" supera largamente al blast radius teórico. El riesgo
  "cae el hub → nada reconcilia" se mitiga porque **el estado desplegado no se pierde**;
  solo se pausa reconciliación hasta restaurar.
- Trade-offs decisivos: equipo plat. muy chico (2 personas no pueden operar 3 Argo CD en
  paralelo), ninguna regulación que exija aislamiento, bajo nº de clusters.
- Riesgos y mitigaciones:
  - Pérdida del hub → Velero backup diario del namespace `argocd`; `kubectl apply -k`
    documentado y testeado trimestralmente.
  - Credenciales del hub = corona → scope-down del SA remoto a un ClusterRole propio;
    OIDC obligatorio para humanos; sin admin local.
  - Dev rompe prod → AppProjects separados por entorno + CODEOWNERS en el repo infra.
- Flujo add-a-cluster: provisionar cluster (Terraform) → crear SA + token → PR con Secret
  declarativo bajo `clusters/<env>/` → merge → ApplicationSet cluster-generator descubre
  y aplica add-ons.

## Org B — GlobalBank → **In-cluster por región** (una Argo CD por cluster, 12 en total)

- Regulación financiera que exige **aislamiento por región** y **blast radius mínimo**:
  un hub por 4 regiones viola el requisito.
- Trade-offs decisivos: regulatorio pesa más que operativo; cada región tiene su propio
  equipo plat., por lo que la "N instalaciones" se reparte (3 Argo CD por equipo
  regional, manejable).
- Riesgos y mitigaciones:
  - Drift de versión de Argo CD entre regiones → repo de infra compartido con un chart
    común parametrizado por `region`; CI exige que todas las regiones estén en la misma
    minor.
  - 12 UIs separadas → dashboard agregador externo (Grafana con `argocd_app_info` de
    todas las regiones).
  - Credenciales regionales → OIDC federado contra el IdP corporativo.
- Flujo add-a-cluster: nueva región = (a) provisionar cluster, (b) instalar Argo CD con
  chart común, (c) apuntar al folder `clusters/<region>/<env>/` del repo infra, (d) el
  mismo repo contiene los AppProjects y ApplicationSets regionales.

## Org C — RetailChain → **Híbrido** (control-plane para corporate, in-cluster-light en edge)

- 3 clusters corporate manejables desde un hub central (misma lógica que Org A).
- 50+ edge con red intermitente → **Flux** por cluster es más apto que Argo CD-por-tienda
  (menos recursos, mejor con reconciliación offline), *o* k3s + Argo CD "mini" sin UI.
  Un hub central registrando 50 clusters remotos con red intermitente fallaría
  (reconciliation loops rotos, token refresh problemático).
- Trade-offs decisivos: hardware RPi-class, red flaky, homogeneidad alta de workload →
  edge quiere algo liviano y autosuficiente; corporate quiere un pane of glass.
- Riesgos y mitigaciones:
  - Fragmentación de herramientas (Argo CD + Flux) → documentar explícitamente la razón
    por tipo de cluster; ADR separado para "edge GitOps engine".
  - Policies drift entre central y edge → repo de infra edge *distinto* al corporate,
    con los mismos manifests fuente pero scope limitado; CI de policy (Kyverno) común.
  - Fallo masivo de tiendas → modo "last-known-good": edge que no puede alcanzar su repo
    sigue con lo último aplicado (comportamiento default de ambos engines).
- Flujo add-a-cluster: corporate = igual que Org A; edge = provisionar k3s con Flux
  bootstrap apuntando al folder `stores/<store-id>/`.

## Tabla comparativa

| Org | Topología             | Nº clusters | Equipo plat. | Blast radius | Mantenimiento |
|-----|-----------------------|-------------|--------------|--------------|---------------|
| A   | control-plane         | 3           | 2 personas   | medio        | 1× Argo CD    |
| B   | in-cluster            | 12          | 2 × 4 regiones | mínimo     | 12× (chart común) |
| C   | híbrido (hub + edge-Flux) | 3 + 50+ | 1 centralizado | bajo       | 1 hub + Flux por edge |

## Qué cambiaría mi recomendación

- Org A → si crece a 15+ clusters, migraría a Argo CD "shardado" por región o pasaría a
  Argo CD Autopilot para contener el crecimiento del repo infra.
- Org B → si se consolidan 2 regiones por M&A y el blast radius se renegocia, podría ir
  a 2 hubs (uno por geo macro) en lugar de 4.
- Org C → si edge gana conectividad estable y los RPi se reemplazan por hardware mayor,
  unificaría todo bajo Argo CD con hub-por-región para edge.

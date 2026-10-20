# EVALUATION — reference (orientativa, no definitiva)

> **Advertencia**: esta referencia da forma a una respuesta "defendible", no "la" respuesta. Verifica siempre los datos en las fuentes oficiales con fecha actual antes de citarlos. La realidad de ambos operadores evoluciona rápido.

## 1. Tabla comparativa (sketch)

| Dimensión | CloudNativePG | Zalando postgres-operator |
|---|---|---|
| Licencia | Apache 2.0 | MIT |
| Patrocinador | EnterpriseDB + comunidad | Zalando + comunidad |
| Estado CNCF | Sandbox / Incubating (verificar fecha) | No CNCF |
| Primer release | 2022 (OSS; descendiente de dev interno de EDB) | ~2017 |
| Modelo de HA | Operador-nativo (sin Patroni), replicación streaming | Basado en Patroni |
| Backup / restore nativo | Barman (object store), continuo | WAL-E/WAL-G/WAL-G |
| PITR | Sí (via Barman) | Sí (via WAL-G) |
| Pooling | `Pooler` CR (PgBouncer) | Deployments separados (PgBouncer) |
| Monitoring | PodMonitor built-in | Prometheus exporter aparte |
| Upgrade minor PG | Via `imageName` + rolling | Idem, Patroni-mediado |
| Upgrade del operador | Simple apply del nuevo manifest; conversion donde aplica | Idem; releases menos frecuentes |
| RBAC | Namespaced + cluster-scoped (CRs) | Cluster-wide típico |
| Documentación | Densa, operacional, buena | Buena pero más dispersa |

## 2. Madurez del proyecto

- **CNPG** destaca por ser *cloud-native-first*: no usa StatefulSets ni Patroni, gestiona Pods directamente y es extremadamente opinable (en el buen sentido). Documentación operacional detallada. Patrocinio EDB, cadencia alta.
- **Zalando** tiene más años de guerra en producción (lo opera Zalando mismo a escala), apoyado en Patroni (estándar de facto para HA Postgres). Más configurabilidad, mayor curva.

## 3. Blast radius

Ambos piden permisos amplios. **CNPG** permite instalación namespaced que acota mejor; **Zalando** históricamente va cluster-wide. En ambos casos, un compromise del operador puede llevar al atacante a controlar las DBs del cluster.

## 4. Backup y restore

**CNPG** lo tiene como ciudadano de primera (Barman integrado, retención declarativa, PITR). **Zalando** confía en WAL-E / WAL-G y requiere más plumbing manual, aunque es flexible.

## 5. Upgrade story

**CNPG** tiene cadencia más rápida y hace esfuerzo explícito con conversion. **Zalando** es más conservador — menos sobresaltos pero también menos features nuevas. Revisar siempre release notes y versiones soportadas.

## 6. Licencia y comunidad

CNPG es **Apache 2.0**, apoyado por EDB. Zalando es **MIT**. Ambas permisivas. Comunidades activas en Slack / GitHub Discussions; CNPG con proyección CNCF más clara.

## 7. Red flags detectadas

- Ambos: dependencia fuerte del object store para backups (si falla, pierdes DR).
- Zalando: documentación un poco dispersa; menor cadencia de releases.
- CNPG: menos años en producción agregada que Zalando; verificar casos pesados.

## 8. Recomendaciones por contexto (defendibles)

### 8.1 Startup pequeña, 1–3 clusters, sin DBA
**Recomendación: CloudNativePG.** Documentación lista, backups de primera, failover autónomo, menos piezas que entender. "Opinable" es bueno cuando no tienes a nadie para opinar.

### 8.2 Empresa grande, 100+ clusters, DBA dedicado, compliance
**Recomendación: depende, con sesgo a Zalando** si ya tienen expertise en Patroni y runbooks heredados. **Si parten de cero**, también CNPG, por mantenimiento y backups integrados.

### 8.3 Edge, muchos clusters pequeños
**Recomendación: CloudNativePG** por footprint y simplicidad; verificar que el runtime de backup (Barman) no sea cuello de botella sin conectividad.

## 9. Limitaciones de esta evaluación

- No se probó failover real ni restore end-to-end.
- Las comunidades y features cambian cada semana — revisar con fecha actual.
- No se evaluaron costos de object storage ni implicancias legales de la licencia en el contexto específico.

# EVALUATION — CloudNativePG vs Zalando postgres-operator

> Fecha de consulta: <!-- TODO (student): YYYY-MM-DD -->
> Versión CNPG consultada: <!-- TODO (student) -->
> Versión Zalando consultada: <!-- TODO (student) -->

## 1. Tabla comparativa

| Dimensión | CloudNativePG | Zalando postgres-operator |
|---|---|---|
| Licencia | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Patrocinador / backing | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Estado CNCF | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Primer release / edad | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Modelo de HA (replicación, failover) | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Backup / restore nativo | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Point-in-time recovery (PITR) | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Connection pooling (PgBouncer) | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Monitoring (Prometheus) | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Upgrade de minor PG | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Upgrade del operador | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Permisos RBAC requeridos | <!-- TODO (student) --> | <!-- TODO (student) --> |
| Documentación operacional | <!-- TODO (student) --> | <!-- TODO (student) --> |

## 2. Madurez del proyecto

### CloudNativePG
<!-- TODO (student): releases, cadencia, issues abiertos/cerrados, maintainers, soporte comercial. Cita URLs. -->

### Zalando postgres-operator
<!-- TODO (student): mismo esquema. -->

## 3. Blast radius

### CloudNativePG
<!-- TODO (student): permisos RBAC a nivel cluster, qué pasa si el operador se compromete. -->

### Zalando postgres-operator
<!-- TODO (student): idem. -->

## 4. Backup y restore

### CloudNativePG
<!-- TODO (student): mecanismo (Barman / otros), destinos (S3/GCS/Azure), PITR, cómo se restaura, caso de falla del operador. -->

### Zalando postgres-operator
<!-- TODO (student): idem. -->

## 5. Upgrade story

<!-- TODO (student): ¿cómo migra uno entre versiones del operador? ¿Hay conversion webhooks? ¿Cuántas versiones N-1 se soportan? ¿Hay breaking changes recientes? -->

## 6. Licencia y comunidad

<!-- TODO (student): licencia (texto exacto), CoC, canal de comunicación activo, política de seguridad / disclosure. -->

## 7. Red flags detectadas

<!-- TODO (student): cualquier cosa que te haría dudar. Si no detectas ninguna, documéntalo explícitamente. -->

## 8. Recomendaciones por contexto

### 8.1 Startup pequeña, 1–3 clusters, equipo plataforma de 2 personas, no DBA dedicado
<!-- TODO (student): recomendación + 2–3 criterios que la justifican. -->

### 8.2 Empresa grande, 100+ clusters, equipo DBA dedicado, exigencias de compliance
<!-- TODO (student): recomendación + 2–3 criterios que la justifican. -->

### 8.3 (opcional) Edge / sucursales, muchos clusters pequeños, poca conectividad
<!-- TODO (student) -->

## 9. Limitaciones de esta evaluación

<!-- TODO (student): qué no probaste (p. ej. failover real), qué información queda sujeta a verificación, horizonte temporal de validez. -->

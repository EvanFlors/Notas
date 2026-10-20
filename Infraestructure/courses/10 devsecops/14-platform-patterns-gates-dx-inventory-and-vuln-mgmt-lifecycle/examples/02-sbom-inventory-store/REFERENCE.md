# SBOM inventory store — referencia

## 1. Schema mínimo (Postgres)

```sql
-- Un registro por servicio desplegado.
CREATE TABLE service (
    name             TEXT PRIMARY KEY,
    team_owner       TEXT NOT NULL,
    repo_url         TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Un registro por (imagen, build).
CREATE TABLE image_build (
    image_digest     TEXT PRIMARY KEY,       -- sha256:...
    service_name     TEXT NOT NULL REFERENCES service(name),
    tag              TEXT NOT NULL,
    built_at         TIMESTAMPTZ NOT NULL,
    git_commit       TEXT NOT NULL,
    signed_identity  TEXT                    -- del cert OIDC de cosign
);

-- Un registro por (imagen, package, version).
CREATE TABLE sbom_component (
    image_digest     TEXT NOT NULL REFERENCES image_build(image_digest),
    package_name     TEXT NOT NULL,
    package_version  TEXT NOT NULL,
    package_type     TEXT NOT NULL,          -- 'os' | 'lang:python' | 'lang:go' | ...
    purl             TEXT NOT NULL,          -- Package URL spec
    first_seen       TIMESTAMPTZ NOT NULL,
    last_seen        TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (image_digest, purl)
);
CREATE INDEX idx_component_name_version ON sbom_component (package_name, package_version);
CREATE INDEX idx_component_purl         ON sbom_component (purl);
```

## 2. Las 6 queries canónicas

### Q1 — "¿Quién corre `openssl 3.0.x`?"

```sql
SELECT DISTINCT ib.service_name
FROM sbom_component c
JOIN image_build ib USING (image_digest)
WHERE c.package_name = 'openssl'
  AND c.package_version LIKE '3.0.%';
```

### Q2 — "¿Qué imágenes aún corren con la versión vulnerable X?"

```sql
SELECT ib.service_name, ib.tag, ib.built_at
FROM sbom_component c
JOIN image_build ib USING (image_digest)
WHERE c.purl = 'pkg:maven/org.apache.logging.log4j/log4j-core@2.14.0'
ORDER BY ib.built_at DESC;
```

### Q3 — "¿Qué servicios tienen imágenes sin firma?"

```sql
SELECT service_name, COUNT(*) AS unsigned_builds
FROM image_build
WHERE signed_identity IS NULL
GROUP BY service_name
HAVING COUNT(*) > 0;
```

### Q4 — "¿Qué paquetes nuevos aparecieron esta semana?"

```sql
SELECT package_name, package_version, MIN(first_seen) AS appeared_at,
       COUNT(DISTINCT image_digest) AS images_affected
FROM sbom_component
WHERE first_seen >= now() - interval '7 days'
GROUP BY package_name, package_version
ORDER BY images_affected DESC;
```

### Q5 — "Blast radius de un cambio al contrato (p.ej. ‘prohibir ruby 2.x’)"

```sql
SELECT ib.service_name, COUNT(*) AS matches
FROM sbom_component c
JOIN image_build ib USING (image_digest)
WHERE c.package_type = 'lang:ruby'
  AND c.package_version LIKE '2.%'
GROUP BY ib.service_name
ORDER BY matches DESC;
```

### Q6 — "¿Qué servicio tiene la mayor edad promedio de dependencias?"

```sql
SELECT ib.service_name,
       AVG(EXTRACT(EPOCH FROM (now() - c.first_seen)) / 86400) AS avg_days
FROM sbom_component c
JOIN image_build ib USING (image_digest)
GROUP BY ib.service_name
ORDER BY avg_days DESC
LIMIT 10;
```

## 3. Flujo de publicación CI → store

```
CI job 'sbom':
  syft <image> -o cyclonedx-json > sbom.cdx.json
  curl -X POST $STORE_URL/upload \
       -H "Authorization: Bearer $TOKEN" \
       -F sbom=@sbom.cdx.json \
       -F image_digest=$DIGEST \
       -F service=$SERVICE_NAME
```

El `upload` endpoint parsea el CycloneDX y hace *upsert* en `sbom_component`.

## 4. Alternativas industriales

- **OWASP Dependency-Track**: UI + alertas automáticas al correlacionar con NVD/OSV; recibe CycloneDX nativo.
- **GUAC**: grafo que une SBOM + provenance (SLSA) + firmas (cosign); respuestas tipo "¿qué imágenes firmadas por `@github-actions` usan librería X?".
- **Snyk / Mend**: comerciales, incluyen remediación guiada.

## 5. Lo que un store **no** reemplaza

- No reemplaza al scanner por PR (ese es el feedback loop corto).
- No reemplaza a los dashboards de MTTR (ese es `vuln-mgmt-dashboard`).
- No reemplaza al runtime SBOM (lo cargado puede diferir de lo instalado).

# Recursos — gcp-05

Referencias oficiales. **Verificar en Fase 4** (consolas, nombres y pricing pueden cambiar).

## Cloud SQL

- Overview: `https://cloud.google.com/sql/docs`
- Cloud SQL Auth Proxy: `https://cloud.google.com/sql/docs/postgres/sql-proxy`
- IAM database authentication (Postgres): `https://cloud.google.com/sql/docs/postgres/iam-authentication`
- Terraform `google_sql_database_instance`: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance`

## AlloyDB

- Overview: `https://cloud.google.com/alloydb/docs/overview`
- Compatibility notes vs Postgres: `https://cloud.google.com/alloydb/docs/reference/extensions`

## Firestore

- Native vs Datastore mode: `https://cloud.google.com/firestore/docs/firestore-or-datastore`
- Data model (collections, documents, subcollections): `https://cloud.google.com/firestore/docs/data-model`
- Composite indexes: `https://cloud.google.com/firestore/docs/query-data/indexing`
- Firestore emulator: `https://cloud.google.com/firestore/docs/emulator`
- Python client: `https://cloud.google.com/python/docs/reference/firestore/latest`

## Bigtable

- Overview: `https://cloud.google.com/bigtable/docs/overview`
- Schema design (row keys!): `https://cloud.google.com/bigtable/docs/schema-design`
- Time-series schema design: `https://cloud.google.com/bigtable/docs/schema-design-time-series`
- Bigtable emulator: `https://cloud.google.com/bigtable/docs/emulator`
- Python client: `https://cloud.google.com/python/docs/reference/bigtable/latest`

## Spanner

- Overview: `https://cloud.google.com/spanner/docs/overview`
- TrueTime & external consistency: `https://cloud.google.com/spanner/docs/true-time-external-consistency`
- Schema (interleaved tables): `https://cloud.google.com/spanner/docs/schema-and-data-model`
- Spanner emulator: `https://cloud.google.com/spanner/docs/emulator`
- Emulator Docker image: `gcr.io/cloud-spanner-emulator/emulator`
- Python client: `https://cloud.google.com/python/docs/reference/spanner/latest`

## Pricing (verificar vigencia)

- Cloud SQL: `https://cloud.google.com/sql/pricing`
- AlloyDB: `https://cloud.google.com/alloydb/pricing`
- Firestore: `https://cloud.google.com/firestore/pricing`
- Bigtable: `https://cloud.google.com/bigtable/pricing`
- Spanner: `https://cloud.google.com/spanner/pricing`

## Lecturas de fondo

- Google TrueTime paper (Spanner, OSDI 2012): `https://research.google/pubs/pub39966/`
- "Choosing the right storage" (Google Cloud architecture): `https://cloud.google.com/architecture/data-lifecycle-cloud-platform`
- DynamoDB -> Firestore migration guide: `https://cloud.google.com/firestore/docs/manage-data/migrate-from-dynamodb`

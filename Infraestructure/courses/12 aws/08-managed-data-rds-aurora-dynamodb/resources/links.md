# Recursos — aws-08

Referencias oficiales y lecturas de apoyo. **Verificar vigencia** antes de citarlas en un ADR real: AWS cambia precios, cuotas y features con frecuencia.

## RDS

- Documentación oficial: <https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html>
- Multi-AZ deployments: <https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html>
- IAM database authentication: <https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html>
- Terraform `aws_db_instance`: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance>

## Aurora

- Overview: <https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html>
- Serverless v2: <https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html>
- Global Database: <https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html>
- Storage layer internals (whitepaper): <https://web.stanford.edu/class/cs245/readings/aurora.pdf>

## DynamoDB

- Developer guide: <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html>
- Best practices (partition key, single-table, GSI): <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html>
- "The DynamoDB Book" — Alex DeBrie (lectura canónica de single-table design).
- `boto3` DynamoDB reference: <https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/dynamodb.html>
- LocalStack DynamoDB coverage: <https://docs.localstack.cloud/user-guide/aws/dynamodb/>

## Pricing (verificar antes de citar)

- RDS pricing: <https://aws.amazon.com/rds/pricing/>
- Aurora pricing: <https://aws.amazon.com/rds/aurora/pricing/>
- DynamoDB pricing: <https://aws.amazon.com/dynamodb/pricing/>

## Herramientas usadas en este módulo

- **Postgres local** vía `docker run postgres:16` (imagen oficial).
- **LocalStack** community para DynamoDB data plane: <https://github.com/localstack/localstack>.
- **Terraform** ≥ 1.5 para `plan` sin credenciales reales (`-refresh=false`, `provider mock`).

## Lecturas tangenciales

- "Designing Data-Intensive Applications" — Martin Kleppmann (contexto general de replicación sincrónica vs asíncrona, cap. 5).
- AWS re:Invent sessions sobre DynamoDB single-table design (buscar talks de Rick Houlihan y Alex DeBrie).

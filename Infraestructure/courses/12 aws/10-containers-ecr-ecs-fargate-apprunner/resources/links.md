# Recursos — aws-10 Containers (ECR, ECS, Fargate, App Runner)

## Documentación oficial

- ECR user guide: https://docs.aws.amazon.com/AmazonECR/latest/userguide/
- ECR lifecycle policies: https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html
- ECR private repository policies: https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-policies.html
- ECS developer guide: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/
- ECS Fargate: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
- Task definition parameters: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
- Task IAM role: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html
- Execution role: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
- App Runner developer guide: https://docs.aws.amazon.com/apprunner/latest/dg/
- App Runner service limits: https://docs.aws.amazon.com/apprunner/latest/dg/service-quotas.html
- ECS Service Connect: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-connect.html
- Cloud Map service discovery: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-discovery.html

## Terraform

- aws_ecr_repository: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
- aws_ecr_lifecycle_policy: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy
- aws_ecs_cluster: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster
- aws_ecs_task_definition: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
- aws_ecs_service: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
- aws_apprunner_service: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apprunner_service

## Imagenes base y OCI

- Docker registry v2 (OSS, el que usamos localmente): https://distribution.github.io/distribution/
- OCI image spec: https://github.com/opencontainers/image-spec

## Lecturas recomendadas

- "Fargate vs EC2 pricing in practice" (Vantage): https://www.vantage.sh/blog/fargate-vs-ec2
- "Choosing ECS vs EKS" (AWS blog): https://aws.amazon.com/blogs/containers/amazon-ecs-vs-amazon-eks-making-sense-of-aws-container-services/
- "App Runner architecture" (AWS blog): https://aws.amazon.com/blogs/containers/
- "The right way to use IAM task roles" (AWS blog): https://aws.amazon.com/blogs/containers/

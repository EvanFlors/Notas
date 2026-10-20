# Recursos — aws-04

Referencias oficiales. **Verificar vigencia en Fase 4** (los enlaces y precios cambian).

## EC2 — oficial AWS

- **EC2 user guide**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html`
- **Instance types explorer**: `https://aws.amazon.com/ec2/instance-types/`
- **Pricing**: `https://aws.amazon.com/ec2/pricing/on-demand/`
- **Nitro system**: `https://aws.amazon.com/ec2/nitro/`
- **Graviton**: `https://aws.amazon.com/ec2/graviton/`

## AMIs

- **AMI SSM parameters** (lista pública mantenida por AWS): `https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-public-parameters-ami.html`
- **Amazon Linux 2023 AMIs**: `https://docs.aws.amazon.com/linux/al2023/ug/ec2.html`
- **Packer** (construir AMIs propias): `https://developer.hashicorp.com/packer/integrations/hashicorp/amazon`
- **EC2 Image Builder** (equivalente AWS-nativo): `https://docs.aws.amazon.com/imagebuilder/`

## SSM Session Manager (en vez de SSH)

- **Session Manager overview**: `https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html`
- **Requisitos del agente SSM**: `https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-ec2.html`
- **IAM policy `AmazonSSMManagedInstanceCore`**: `https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html`
- **VPC endpoints necesarios en subnet privada**: `https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html`

## IMDSv2

- **Instance metadata and user data**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html`
- **IMDSv2 — por qué**: `https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/`
- **Capital One breach (contexto IMDSv1 → SSRF)**: `https://krebsonsecurity.com/2019/08/what-we-can-learn-from-the-capital-one-hack/`

## User-data y cloud-init

- **User data en Linux**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html`
- **cloud-init docs**: `https://cloudinit.readthedocs.io/`
- **Formatos aceptados (bash, cloud-config, multipart)**: `https://cloudinit.readthedocs.io/en/latest/explanation/format.html`

## EBS

- **EBS volume types**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html`
- **Default encryption**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html`
- **Snapshots**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSSnapshots.html`

## IAM para EC2

- **Using instance profiles**: `https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2.html`
- **STS `GetCallerIdentity`**: `https://docs.aws.amazon.com/STS/latest/APIReference/API_GetCallerIdentity.html`

## Launch templates y Auto Scaling

- **Launch templates**: `https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/launch-templates.html`
- **Auto Scaling Groups**: `https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html`
- **Instance refresh (rolling update)**: `https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh.html`

## Terraform AWS provider — referencias

- **`aws_instance`**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance`
- **`aws_launch_template`**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template`
- **`aws_iam_instance_profile`**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile`
- **`aws_ssm_parameter` (data source)**: `https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter`

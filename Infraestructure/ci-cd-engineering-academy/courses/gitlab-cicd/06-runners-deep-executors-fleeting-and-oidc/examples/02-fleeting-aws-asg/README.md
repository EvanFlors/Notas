# Ejemplo 02 — Fleeting con AWS Auto Scaling Group

Fleeting es el sucesor oficial de `docker-machine`. Un runner "controlador" vive en una VM pequeña y, cuando llegan jobs, pide más instancias a un **ASG** vía el plugin `fleeting-plugin-aws`.

Este ejemplo muestra el `config.toml` del runner controlador y el **policy mínimo** que debe tener el role del controlador para operar el ASG.

## `config.toml` del controlador

```toml
concurrent = 50
check_interval = 5
log_level = "info"

[[runners]]
  name = "fleeting-aws-eu-west-1"
  url = "https://gitlab.com/"
  token = "glrt-REEMPLAZA_ESTO"
  executor = "docker-autoscaler"
  shell = "bash"

  [runners.autoscaler]
    plugin = "aws"
    capacity_per_instance = 2
    max_use_count = 20
    max_instances = 10

    [runners.autoscaler.connector_config]
      username = "ec2-user"
      use_static_credentials = false
      timeout = "10m0s"

    [runners.autoscaler.plugin_config]
      name    = "runners-asg-eu-west-1"
      profile = "default"
      region  = "eu-west-1"

    [[runners.autoscaler.policy]]
      idle_count    = 1
      idle_time     = "20m0s"
      scale_factor  = 0.0
      scale_factor_limit = 0

  [runners.docker]
    image      = "alpine:3.20"
    privileged = false
    disable_cache = false
    volumes    = ["/cache"]
```

Lectura:

- **`executor = "docker-autoscaler"`** es el ejecutor que delega el aprovisionamiento al plugin de Fleeting.
- **`capacity_per_instance = 2`** cada VM del ASG corre hasta 2 jobs en paralelo.
- **`max_use_count = 20`** tras 20 jobs la VM se recicla (defensa contra fugas de estado y caches sucias).
- **`idle_count = 1`** mantiene siempre una VM "caliente" para arranque rápido.
- **`max_instances = 10`** límite duro de tamaño del pool.

## IAM policy del role del controlador

Mínimo necesario para que el plugin opere el ASG:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "FleetingReadASG",
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeScalingActivities",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "FleetingWriteASG",
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup"
      ],
      "Resource": "arn:aws:autoscaling:eu-west-1:111122223333:autoScalingGroup:*:autoScalingGroupName/runners-asg-eu-west-1"
    }
  ]
}
```

Nota el **`Resource:` restringido** al ASG concreto en el bloque de escritura. Un controlador no tiene por qué poder matar otros ASGs de la cuenta.

## Instalación del plugin en el host del controlador

Fleeting plugin NO es un servicio aparte: es un binario invocado por el runner. En la VM del controlador:

```bash
curl -L -o /usr/local/bin/fleeting-plugin-aws \
  https://gitlab.com/gitlab-org/fleeting/plugins/aws/-/releases/vX.Y.Z/downloads/fleeting-plugin-aws-linux-amd64
chmod +x /usr/local/bin/fleeting-plugin-aws
```

Si falta, el runner arranca pero loguea `plugin "aws" not found` y no toma jobs.

## Cuándo adoptar Fleeting (y cuándo no)

- **Sí**: necesitas VM entera (test de drivers, Windows, firmware), ya operas AWS y prefieres no mantener un cluster K8s.
- **No**: tu caso cabe en pods (99% de pipelines web). K8s + `kubernetes` executor es más simple.

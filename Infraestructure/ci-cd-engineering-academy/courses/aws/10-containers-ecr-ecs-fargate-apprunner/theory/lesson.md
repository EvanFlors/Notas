# aws-10 — Lección: contenedores en AWS sin Kubernetes

> 12 secciones. Prerrequisitos: `aws-02`, `aws-03`, `aws-07`, curso **docker**.

---

## 1. El problema que resuelven ECR + ECS + Fargate + App Runner

Dado un contenedor Docker funcional en tu laptop, correrlo "en AWS" implica resolver cuatro problemas distintos:

1. **Dónde vive la imagen.** No puedes depender de Docker Hub como fuente de verdad para producción: necesitas control sobre quién *pushea*, quién *pullea*, qué se escanea, cuánto tiempo se retienen tags viejos, y en qué regiones se replica.
2. **Qué proceso ejecuta la imagen.** Alguien tiene que iniciar el contenedor, pasarle variables de entorno, montar logs, parar y reiniciar en errores, saber cuántas réplicas correr.
3. **Dónde corre físicamente.** Hace falta cómputo: ya sea EC2 (nodos tuyos) o Fargate (el plano de datos lo pone AWS).
4. **Cómo le llega el tráfico.** Un load balancer con health checks, TLS, un target group que sepa dar de alta/baja las IPs dinámicas de las tareas.

AWS parcela estos cuatro problemas en productos distintos:

| Problema | Producto AWS |
|----------|--------------|
| Dónde vive la imagen | **ECR** (registry gestionado) |
| Qué proceso ejecuta | **ECS** (orquestador) o **App Runner** (opinionado) |
| Dónde corre físicamente | **EC2** o **Fargate** (como *launch type* de ECS/App Runner) |
| Cómo llega el tráfico | **ALB** + **ECS service** (target group por IP) o App Runner (ya trae HTTPS) |

Este módulo cubre **todo lo que no es EKS**. Cuando necesitas Kubernetes real (CRDs, operadores, mallas de servicio ricas), pasas a `aws-11-eks-in-depth`. Para la gran mayoría de servicios HTTP / workers / jobs, lo de este módulo basta y es más barato en complejidad operacional.

> **Idea clave:** la pregunta "¿Lambda, App Runner, ECS/Fargate, ECS/EC2 o EKS?" se responde eligiendo **cuánto control vs cuánta operación quieres**. Lambda = menos control, menos operación. EKS = más control, más operación. ECS/Fargate está en el medio y es la **respuesta por defecto** sensata.

---

## 2. ECR: la pieza invisible pero crítica del supply chain

**ECR (Elastic Container Registry)** es un *registry* OCI gestionado. Lo que lo hace relevante no es "guardar imágenes" (eso lo hace cualquier registry), sino que:

- Vive **dentro de IAM**. No hay "usuario del registry": el permiso de *push* y *pull* es una política IAM. CI usa un rol vía OIDC (ver `aws-16-devsecops-on-aws/01-full-oidc-pipeline-no-keys/`); ECS/Fargate *pullea* vía el **execution role**.
- Soporta **scan on push** (básico, con la base de datos de vulnerabilidades de Clair; o "enhanced" con Inspector por un coste). Ocurre fuera de banda — el *push* no se bloquea; la alerta llega por EventBridge.
- Tiene dos sabores: **privado** (lo normal) y **público** (`public.ecr.aws/...` — para distribuir imágenes open-source). No se mezclan: son endpoints distintos.
- Permite **replication** cross-región y cross-cuenta — útil para desplegar en múltiples regiones sin volver a *pushear* desde CI N veces.
- Las **lifecycle policies** controlan el coste de almacenamiento: eliminan tags por antigüedad o por cantidad (p. ej. "conservar solo las últimas 20 imágenes `prod-*`, borrar todo lo `pr-*` después de 7 días").

### Autenticación: el baile del login

ECR no acepta `docker push` directo. Requiere un **token** de 12 horas obtenido con `aws ecr get-login-password`. El flujo típico desde CI (OIDC, sin keys estáticas):

```bash
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
docker tag myapp:latest "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/myapp:$SHA"
docker push "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/myapp:$SHA"
```

En este módulo lo simulamos con un **`registry:2` local** (el registry open-source de Docker) escuchando en `127.0.0.1:5000`. La semántica del push es idéntica — lo único que cambia es el `docker login` (en local no hace falta).

### Lifecycle policy: dónde se va la plata

Una imagen de 500 MB a $0.10/GB-mes cuesta ~ $0.05 al mes. Suena a nada hasta que CI empuja 300 builds al día durante un año y tienes 100.000 tags viejos acumulados = 50 TB = $5.000/mes solo en ECR. La `lifecycle-policy.json` se escribe una vez y se aplica a cada repo:

```json
{
  "rules": [
    { "rulePriority": 1,
      "description": "Mantener las ultimas 30 imagenes prod-*",
      "selection": { "tagStatus": "tagged", "tagPrefixList": ["prod-"],
                     "countType": "imageCountMoreThan", "countNumber": 30 },
      "action": { "type": "expire" } },
    { "rulePriority": 2,
      "description": "Borrar imagenes pr-* despues de 7 dias",
      "selection": { "tagStatus": "tagged", "tagPrefixList": ["pr-"],
                     "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 7 },
      "action": { "type": "expire" } },
    { "rulePriority": 3,
      "description": "Borrar untagged despues de 1 dia",
      "selection": { "tagStatus": "untagged",
                     "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 1 },
      "action": { "type": "expire" } }
  ]
}
```

La actividad 02 trabaja esto en detalle.

---

## 3. ECS: cluster, task definition, service

ECS tiene **tres recursos primarios** que hay que distinguir:

1. **Cluster** — un *namespace* lógico. No es un cluster al estilo Kubernetes: es básicamente un contenedor para servicios y tareas. Fargate y EC2 pueden coexistir en el mismo cluster.
2. **Task definition** — la **receta** inmutable que describe uno o más contenedores: imagen, CPU/memoria, variables de entorno, puertos, logging, volúmenes, roles IAM. Cada actualización crea una **nueva revisión** (`myapp:1`, `myapp:2`, …). Las revisiones viejas quedan como historial.
3. **Service** — mantiene **N tareas vivas** de una task definition dada; actualiza (rolling / blue-green con CodeDeploy), autoscalea, se registra en un target group del ALB.

Diferencia con Kubernetes a tener en cabeza:

| Concepto K8s | Equivalente ECS |
|--------------|-----------------|
| Pod | Task (una task puede tener N contenedores, igual que un pod) |
| Deployment | Service |
| Image spec en Pod | Container definition dentro de la task definition |
| HorizontalPodAutoscaler | Application Auto Scaling target + policy sobre el service |
| Service (K8s) + Ingress | ALB + target group (asociado al ECS service) |
| ServiceAccount con IRSA | **Task role** |
| Node | Fargate (no hay nodo visible) o EC2 instance |

### Anatomía mínima de una task definition

```json
{
  "family": "capstone-api",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/capstoneApiTaskRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "ACCOUNT.dkr.ecr.REGION.amazonaws.com/capstone-api:SHA",
      "portMappings": [ { "containerPort": 8000, "protocol": "tcp" } ],
      "essential": true,
      "environment": [
        { "name": "APP_ENV", "value": "prod" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/capstone-api",
          "awslogs-region": "REGION",
          "awslogs-stream-prefix": "api"
        }
      }
    }
  ]
}
```

Puntos a interiorizar:

- **`networkMode: awsvpc`** es prácticamente obligatorio en Fargate: cada tarea obtiene **su propia ENI** con IP privada en una subred tuya. No hay `bridge` ni `host` como en EC2 clásico.
- **`cpu` y `memory`** en Fargate solo aceptan **combinaciones predefinidas**: 256/512-1024-2048, 512/1024-4096, 1024/2048-8192, … (si pones valores arbitrarios, falla el `RunTask`).
- **`executionRoleArn` y `taskRoleArn`** son dos roles distintos — § 5 lo detalla.
- **`essential: true`** en un contenedor significa que si ese contenedor muere, la tarea entera muere y el service la reemplaza.
- **`logConfiguration` con `awslogs`** manda stdout/stderr a un *log group* de CloudWatch Logs. Sin esto, los logs se pierden.

---

## 4. Fargate vs EC2 (launch types)

ECS corre tareas sobre dos *launch types* intercambiables:

| Dimensión | **Fargate** | **EC2** |
|-----------|-------------|---------|
| Quién gestiona nodos | AWS (invisible) | Tú (AMI, patching, ASG, drain) |
| Facturación | Por vCPU-segundo + GB-segundo de la tarea | Por hora de instancia (con *overcommit* posible) |
| Densidad | 1 ENI por tarea; sin overcommit | N tareas por instancia; mejor *bin packing* |
| Boot time | 30–60 s | Pod empieza en segundos si el nodo ya está |
| GPU / instance types especiales | Limitado | Cualquier tipo EC2 (G, P, M6, etc.) |
| Daemon sets (log/metric agent por nodo) | No aplican (no hay nodo) | Posibles (`cadvisor`, `fluentbit`, exporters) |
| `privileged`, `--cap-add`, `--pid=host` | **No permitido** | Permitido |
| Montaje de volumen EFS | Sí (desde 2020) | Sí |
| Mejor para | APIs HTTP, workers, jobs, "quiero menos devops" | Alta densidad, GPU, cargas pesadas 24/7, requerimientos de kernel |

Regla de pulgar:

- Empieza en **Fargate**. Cambia a **EC2** cuando el coste del *overhead* Fargate (hay un ~30 % de margen por encima del EC2 equivalente, aproximado) o un requerimiento duro (GPU, DaemonSet, `privileged`) te empuje.
- Un cluster puede tener **ambos**: APIs en Fargate, workers de IA en EC2 con GPU, con providers de capacidad separados.

### El coste real: por qué Fargate es más barato de lo que parece

La comparación "vCPU-hora Fargate vs vCPU-hora EC2 reservado" es injusta: ignora el equipo de 1–2 ingenieros que mantiene los nodos EC2 (bootstrap, patching, upgrades de AMI, resolución de capacidad). Para una organización pequeña, el *premium* de Fargate se devuelve en salarios no gastados en SRE de nodo.

---

## 5. Execution role vs task role (el error IAM #1 en ECS)

Es la distinción más mal entendida de ECS. Vale la pena detenerse:

```
┌─────────────────────────────────────────────────────────────┐
│  Fargate agent (code AWS) usa EXECUTION ROLE para:          │
│    - docker pull desde ECR (ecr:GetAuthorizationToken,      │
│                             ecr:BatchGetImage, ...)         │
│    - escribir logs a CloudWatch (logs:CreateLogStream,      │
│                                  logs:PutLogEvents)         │
│    - resolver secretos de Secrets Manager / SSM             │
│      inyectados por 'secrets' en la task definition         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Codigo de la app dentro del contenedor usa TASK ROLE para: │
│    - s3:PutObject en el bucket de reports                   │
│    - dynamodb:Query en la tabla de sesiones                 │
│    - sqs:ReceiveMessage si es un worker                     │
│    - cualquier llamada AWS SDK desde el proceso             │
└─────────────────────────────────────────────────────────────┘
```

**Reglas prácticas:**

1. **Execution role** típicamente se llama `ecsTaskExecutionRole` y lleva la managed policy `AmazonECSTaskExecutionRolePolicy`. Es *compartible* entre múltiples servicios porque no da acceso a datos del negocio.
2. **Task role** es **específico por servicio**. `payments-api` tiene permisos a su KMS y su DynamoDB; `reports-worker` tiene permisos a su S3. Nunca compartir task roles entre servicios.
3. Síntomas de confundirlos:
   - Si el *execution role* no tiene permisos ECR: la tarea nunca arranca. Error: `CannotPullContainerError`.
   - Si el *task role* no tiene permisos a los servicios AWS que llama el código: la app arranca pero las llamadas AWS fallan con `AccessDenied` en runtime.
4. **El código nunca pone credenciales**. El SDK de AWS resuelve credenciales vía el **endpoint de metadatos de la task** (`169.254.170.2`), que devuelve credenciales temporales del task role.

### El *trust policy* que une todo

Ambos roles necesitan un *trust policy* que permita a **ecs-tasks.amazonaws.com** asumirlos:

```json
{ "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ecs-tasks.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]}
```

Si falta, el task se queda en `PROVISIONING` para siempre.

---

## 6. Networking: `awsvpc`, security groups y ALB-by-IP

En Fargate, el modo de red **`awsvpc`** es el único soportado y cambia la manera de pensar:

- Cada tarea recibe **su propia ENI** con IP privada en una subred.
- Puertos del contenedor son los puertos de la ENI (no hay NAT a nivel de host).
- Los **security groups se aplican a la tarea**, no a un host compartido.
- Dos tareas en la misma instancia (en EC2) no pueden coexistir con `awsvpc` si usan el mismo puerto — pero esto ya no importa en Fargate (siempre hay 1 tarea por "nodo invisible").

Consecuencias:

- **Subred para tareas** debe tener IPs suficientes. Si corres 100 tareas, necesitas ≥ 100 IPs libres por subred/AZ. `/24` (256 IPs) se queda chico rápido.
- **No** uses subredes públicas para tareas si tus tareas no deben ser accesibles directamente desde Internet. Pon tareas en **subred privada**, con NAT Gateway para egress, y el ALB en **subred pública**.
- **ALB al target group** debe hablar por **IP** (`target_type = "ip"`), no por `instance`. ECS registra/deregistra IPs de ENIs a medida que escalan las tareas.
- El **security group del ALB** permite 80/443 desde Internet; el **security group de las tareas** permite solo el puerto de la app (p. ej. 8000) desde el **security group del ALB** (regla *source=sg-alb*, no CIDR). Esta es la cadena que confina el blast radius.

### Service discovery (Cloud Map)

Para que un servicio ECS encuentre a otro **sin** pasar por ALB (p. ej. llamadas internas entre microservicios), ECS integra con **AWS Cloud Map**: cada tarea se registra en un *namespace* privado (`api.capstone.internal`) y los demás resuelven por DNS. Alternativa: **Service Connect** (más nuevo, con proxy sidecar inyectado y métricas automáticas). Para dos servicios y poco tráfico cruzado, Cloud Map basta.

---

## 7. ALB target group por servicio: por qué cada service es 1:1 con un TG

El target group es la lista de IPs que reciben tráfico. ECS lo mantiene actualizado cada vez que una tarea arranca o muere. El acoplamiento es:

- **1 ECS service ↔ 1 target group ↔ 1 regla del ALB listener.**
- La regla del listener matchea por host header o path prefix (`/api/*` → `tg-api`, `/web/*` → `tg-web`).
- Si cambias la cantidad deseada del service a 5, el target group tendrá 5 IPs; a 0, cero IPs y el ALB devuelve 503.
- `deregistration_delay` del TG (default 300 s) es el tiempo que el ALB espera antes de cerrar conexiones a una tarea que se está yendo (*drain*). Baja a 30–60 s para APIs sin conexiones largas; sube para WebSocket.

### Health checks: el gotcha más común

El ALB marca una IP como *healthy* después de N checks correctos (`healthy_threshold`) y *unhealthy* después de M fallidos. **Si tu health check es `/health` pero tu app tarda 10 s en arrancar y el health check dispara cada 5 s con `unhealthy_threshold=2`, el ALB mata la tarea antes de que termine de arrancar.** Soluciones:

- Define un `startup` endpoint distinto o aumenta `healthy_threshold`.
- Define `health_check_grace_period_seconds` en el ECS service (default 0): le dice al service "ignora el estado del TG durante los primeros X segundos de la tarea".

---

## 8. App Runner: la ruta sin fricción

**App Runner** es la respuesta de AWS a *"solo quiero correr mi API, no quiero diseñar nada"*. Tú das:

- Una **imagen en ECR** (privado o público) **o** un repo GitHub con `apprunner.yaml`.
- CPU/memoria (combinaciones limitadas: 0.25 vCPU/0.5 GB, 1 vCPU/2 GB, …).
- Variables de entorno y, opcionalmente, secretos.
- Un health check path.

AWS resuelve:

- Build (si eliges GitHub con buildpacks).
- Pull de la imagen.
- Correr N instancias con auto-scaling simple (requests concurrentes).
- **Terminación TLS** automática con certificado gestionado.
- **URL pública HTTPS** (`https://xxxxx.region.awsapprunner.com`) o dominio custom con cert ACM.
- Deploy continuo si marcas "auto-deploy" ante nuevos tags.

Lo que **sacrificas** respecto a ECS/Fargate:

| Palanca | ECS/Fargate | App Runner |
|---------|-------------|------------|
| Red | VPC completa, subredes, SG, egress NAT | VPC Connector opcional, resto gestionado |
| Load balancer | ALB con reglas finas, WAF | HTTPS gestionado, sin reglas de path |
| Múltiples contenedores por tarea | Sí (sidecars) | **No** (1 contenedor) |
| Autoscaling custom | Target tracking sobre cualquier métrica | Solo *concurrent requests* |
| Observabilidad granular | CloudWatch Logs + Container Insights + sidecars | Logs básicos y métricas HTTP |
| Jobs/batch | Sí | **No** (solo HTTP de larga duración) |
| Precio por idle | Pagas tareas corriendo | Baja a 0 provisioned (opt-in) pero con cold start |

**Cuándo elegir App Runner:**

- APIs HTTP de 1 contenedor sin requerimientos exóticos.
- Equipo sin devops dedicado.
- Prototipos y servicios internos de bajo volumen.
- "Quiero una URL HTTPS en 5 minutos a partir de mi repo".

**Cuándo NO elegir App Runner:**

- Múltiples contenedores (sidecar de proxy, agente OTel, exporter).
- Workers / jobs no-HTTP.
- Necesitas control de red fino (NAT dedicado, VPC endpoints raros).
- Necesitas blue/green con CodeDeploy.
- Cargas con autoscaling por métricas custom (profundidad de cola, latencia P99).

---

## 9. ECS vs EKS vs Lambda vs App Runner (la decisión real)

| Opción | Fortaleza | Debilidad | "Encaja cuando…" |
|--------|-----------|-----------|-------------------|
| **Lambda** | Sin servidor; pago por invocación; cold start aceptable | 15 min max; sin estado persistente; concurrencia por *account* | Eventos esporádicos, cron, webhooks, backends simples con DynamoDB |
| **App Runner** | Opinionado; 1 click; HTTPS incluido | 1 contenedor; HTTP-only; red limitada | APIs HTTP triviales sin devops |
| **ECS / Fargate** | Flexible pero sin cluster-ops; multi-contenedor; ALB rico | Lock-in moderado a AWS (task definition ≠ pod spec) | **La respuesta por defecto** para servicios HTTP y workers persistentes |
| **ECS / EC2** | Densidad; GPU; `privileged` | Operas los nodos | Alta densidad, GPU, workloads con requerimientos de kernel |
| **EKS** | Kubernetes real; portabilidad; ecosystem CNCF | Más cluster-ops; coste del control plane; curva | Equipo ya K8s-fluido; multi-cloud; necesidad de CRDs/operadores |

Un algoritmo mental honesto:

1. ¿**Evento esporádico** y respuesta < 15 min? → **Lambda**.
2. ¿**API HTTP** de 1 contenedor sin devops? → **App Runner**.
3. ¿**Servicio persistente**, posiblemente multi-contenedor, sin requerir K8s puro? → **ECS/Fargate**.
4. ¿Necesitas **GPU, privileged, densidad extrema**? → **ECS/EC2**.
5. ¿**K8s nativo** es un requisito duro del equipo o del cliente, o necesitas **CRDs/operadores**? → **EKS**.

Esta pregunta se trabaja como entregable de evaluación del módulo.

---

## 10. Observabilidad: lo mínimo

Un servicio ECS/Fargate sano tiene **4 fuentes** de telemetría:

1. **CloudWatch Logs** vía `awslogs` driver — stdout/stderr del contenedor en un log group. Siempre configurarlo.
2. **CloudWatch Container Insights** — métricas de CPU/mem/red por servicio y por tarea, agregadas. Opt-in (hay coste). Para producción, encenderlo.
3. **ALB access logs** a S3 — latencia por request, códigos de respuesta, target IP que respondió. Esencial para debugar P99.
4. **X-Ray o OTel** vía *sidecar* — distributed tracing. Un sidecar `aws-otel-collector` en la task definition recibe spans del contenedor principal por localhost y los exporta a X-Ray / backend. Complementa, no sustituye, a Container Insights.

El módulo `aws-12-observability-cloudwatch-xray-cloudtrail` lo profundiza; aquí basta con saber que los logs **sí** se olvidan si no configuras `logConfiguration` y hay que dimensionar retention.

---

## 11. Ventajas y limitaciones honestas

**Ventajas (ECS/Fargate):**

- **Simplicidad operacional real** vs K8s: no hay cluster que mantener; la *control plane* es AWS.
- **IAM primera clase**: cada tarea con su rol, sin IRSA ni OIDC manual.
- **Facturación granular** por vCPU-s / GB-s — fácil de atribuir por servicio.
- **Integración nativa** con ALB, Secrets Manager, Parameter Store, Service Connect.
- **Portabilidad razonable**: la *imagen* es portable; solo la "cáscara" (task def) es específica. Migrar a K8s más tarde no requiere reescribir código.

**Limitaciones y riesgos:**

- **Vendor lock-in de orquestación**: la `task-definition.json` no es portable a K8s. Si existe la mínima duda de que acabarás en EKS o multi-cloud, pondera.
- **Boot time Fargate (30–60 s)** limita el autoscaling reactivo a picos muy rápidos. Para spikes, pre-escalar o usar provisioned concurrency en App Runner (más cara).
- **Precio Fargate** vs EC2 reservado puede ser 30 % más caro a vCPU equivalente. En cargas 24/7 enormes, EC2 reservado o Savings Plan pesa.
- **ECS no tiene operadores**. Si tu workload necesita CRDs (Istio, Argo CD, Flink Operator), ECS no es el sitio.
- **App Runner es una caja negra**: cuando falla, el *debuggability* es limitado. No es apto para cargas críticas con SLOs estrictos.

---

## 12. Qué sigue (y qué llevarse)

Al terminar este módulo deberías poder:

- Explicar **ECR + ECS + Fargate + App Runner** sin confundirlos con K8s.
- Escribir una **task definition** válida con `awsvpc`, dos roles separados, logging y portMappings.
- Dibujar la topología **ALB (público) → ECS service (privado) → RDS/S3 (acceso IAM)**.
- Justificar la elección entre **Lambda / App Runner / ECS Fargate / ECS EC2 / EKS** con *drivers* explícitos.
- Diseñar una **lifecycle policy** de ECR con reglas por prefijo de tag y antigüedad.

Síntesis final de una línea:

> **ECS/Fargate es la ruta de menor fricción para correr contenedores en AWS cuando no se justifica Kubernetes; ECR es su registry; App Runner es la versión aún más opinionada para APIs simples; y la elección se juega en cuánto control vs cuánta operación quieres asumir.**

Todo el módulo es cómo materializar esa frase sin disparar un solo céntimo de factura AWS real.

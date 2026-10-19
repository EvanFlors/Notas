# README-INTENT — webapp AMI (Packer + Ansible)

> Documento de intención: qué horneamos en la AMI, qué dejamos para runtime y cómo Terraform consume el resultado.

## Que se hornea

- **nginx** (binario + configuración por defecto `nginx.conf` con un endpoint `/` que responde `ok <version>`).
- **python3** (requerido por Ansible y por scripts internos de arranque).
- **amazon-cloudwatch-agent** (agente de métricas y logs — se configura al arrancar vía user-data, pero el binario viene horneado).
- **Usuario de servicio `webapp`** (system user sin shell interactiva, para que la app no corra como `root`).
- **Marcador de versión** en `/etc/webapp-version` — útil para debugging ("¿qué AMI es esta?").

Lo que se hornea es *todo lo que no cambia entre instancias de la misma AMI*. Si cambia, es señal de que debería ir en una AMI nueva.

## Que NO se hornea

- **Secretos** (DB passwords, API tokens, certificados privados). Van vía **AWS Secrets Manager** o **Parameter Store**, consultados por la app al arrancar (SDK o `aws-cli`), **nunca** en el repo ni en la AMI.
- **Config específica del entorno** (dev/stg/prod) — se inyecta por **user-data** del `aws_instance` o por `aws_launch_template`.
- **Hostname / IP** (lo asigna EC2 al arrancar).
- **Certificados TLS públicos** si rotan solos vía ACM / cert-manager.
- **Logs persistentes** — van a CloudWatch Logs vía el agente, no a disco local (el disco local de una instancia inmutable es efímero por diseño).

## Provisioner ansible vs ansible-local

Elegimos `provisioner "ansible"` (no `ansible-local`) por 3 razones:

1. **La imagen base no necesita Ansible instalado.** `ansible-local` requiere `python3` + `ansible-core` en la AMI base, lo que engorda el AMI y añade superficie de ataque innecesaria (una vez horneada la imagen, nunca más corremos Ansible dentro).
2. **El runner de Packer (nuestro CI) ya tiene Ansible.** Es más fácil mantener versiones consistentes de `ansible-core` en el runner que en N AMIs base.
3. **Debugging más fácil.** Si el playbook falla, el output va al log del runner de Packer, no hay que entrar al host temporal.

Cuándo preferiríamos `ansible-local`:

- Red muy restringida donde el runner de Packer **no puede** abrir SSH al host temporal (ej. VPC privada sin NAT).
- Entornos airgapped donde no hay cómo que el runner tenga Ansible pero sí hay un AMI base con todo pre-instalado.

## Como consume Terraform el ami_id

Flujo en CI:

1. `packer init .` descarga plugins (una vez por runner).
2. `packer validate -var "app_version=$GITHUB_SHA" .` — chequeo offline.
3. `packer build -var "app_version=$GITHUB_SHA" .` — construye la AMI; al terminar escribe `packer-manifest.json` gracias al `post-processor "manifest"`.
4. Extraer el `ami_id`:
   ```bash
   AMI_ID=$(jq -r '.builds[-1].artifact_id' packer-manifest.json | cut -d: -f2)
   ```
   El `artifact_id` tiene formato `<region>:<ami-id>`; cortamos por `:`.
5. Pasar a Terraform:
   ```bash
   terraform apply -auto-approve -var "ami_id=$AMI_ID"
   ```

En el repo de Terraform, el `aws_launch_template` consume la variable:

```hcl
variable "ami_id" { type = string }

resource "aws_launch_template" "webapp" {
  name_prefix   = "webapp-"
  image_id      = var.ami_id
  instance_type = "t3.small"
  # user_data con config por entorno + fetch de secretos ...
}
```

**Rollback** = `terraform apply -var "ami_id=<ami-id-anterior>"`. La AMI anterior sigue existiendo en la cuenta hasta que la limpie una policy de lifecycle o un paso manual.

## Nota sobre idempotencia

El playbook de arriba no usa `shell:` ni `command:` sueltos — todos los módulos (`dnf`, `user`, `copy`, `systemd`) son idempotentes. Si se corriera 2 veces consecutivas sobre el mismo host, la segunda daría `changed=0`. Esto es importante porque Packer puede reintentar un provisioner si hay fallo transitorio, y una task no-idempotente puede dejar el host en estado raro.

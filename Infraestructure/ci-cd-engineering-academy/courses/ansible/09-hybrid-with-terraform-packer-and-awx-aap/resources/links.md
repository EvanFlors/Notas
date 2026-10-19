# Recursos — ans-09

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (versiones de Packer, plugins y pricing de AAP pueden cambiar).

## Terraform + Ansible (patrón mutable)

- **Ansible dynamic inventory (AWS EC2 plugin)**: `https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html`
- **Ansible dynamic inventory (GCP)**: `https://docs.ansible.com/ansible/latest/collections/google/cloud/gcp_compute_inventory.html`
- **Ansible dynamic inventory (Azure)**: `https://docs.ansible.com/ansible/latest/collections/azure/azcollection/azure_rm_inventory.html`
- **amazon.aws collection**: `https://docs.ansible.com/ansible/latest/collections/amazon/aws/`
- **HashiCorp Terraform docs**: `https://developer.hashicorp.com/terraform/docs`

## Packer + Ansible (patrón inmutable)

- **Packer tutorial (HCL2)**: `https://developer.hashicorp.com/packer/tutorials`
- **Packer Ansible provisioner**: `https://developer.hashicorp.com/packer/integrations/hashicorp/ansible/latest/components/provisioner/ansible`
- **Packer `ansible-local` provisioner**: `https://developer.hashicorp.com/packer/integrations/hashicorp/ansible/latest/components/provisioner/ansible-local`
- **Packer AWS AMI builder**: `https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs`
- **Packer post-processor manifest**: `https://developer.hashicorp.com/packer/docs/post-processors/manifest`

## AWX / Ansible Automation Platform

- **AWX project (GitHub)**: `https://github.com/ansible/awx`
- **AWX Operator** (install on Kubernetes): `https://github.com/ansible/awx-operator`
- **Red Hat AAP docs**: `https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/`
- **AAP vs AWX comparación** (varía por release): buscar "AWX vs AAP" en Red Hat blog, edición reciente.
- **Pricing AAP**: `https://www.redhat.com/en/technologies/management/ansible/pricing` (verificar vigente).

## Event-Driven Ansible

- **ansible-rulebook docs**: `https://ansible.readthedocs.io/projects/rulebook/en/stable/`
- **ansible.eda collection**: `https://ansible.readthedocs.io/projects/eda-collection/en/stable/`
- **Blog Red Hat — EDA overview**: `https://www.redhat.com/en/topics/automation/what-is-event-driven-ansible`

## Comparación con alternativas

- **GitOps con Argo CD**: `https://argo-cd.readthedocs.io/en/stable/`
- **GitOps con Flux**: `https://fluxcd.io/`
- **Helm**: `https://helm.sh/docs/`

## Para los módulos previos (contexto)

- Si no completaste `ans-04`, al menos lee:
  - `ans-04` README y la lección (roles).
- Si no completaste `ans-07`, al menos lee:
  - `ans-07` sobre idempotencia (es imprescindible para que un provisioner de Packer funcione bien).

## Checklist de verificación requerida en Fase 4

- Versión actual del plugin `ansible` de Packer (y matriz de compatibilidad con `ansible-core`).
- Versión actual de `amazon.aws` y breaking changes en el inventory plugin.
- Estado GA / preview de **Event-Driven Ansible** y plugins (Kafka, webhook, Alertmanager).
- Precio actual de **AAP** y modelo de licenciamiento (por nodo gestionado).
- Si **AAP** se despliega ya como SaaS gestionado por Red Hat (además de self-hosted).
- Alternativas vigentes a Packer para images (p. ej. image-builder nativo de EC2, OpenStack image-builder, Osbuild).

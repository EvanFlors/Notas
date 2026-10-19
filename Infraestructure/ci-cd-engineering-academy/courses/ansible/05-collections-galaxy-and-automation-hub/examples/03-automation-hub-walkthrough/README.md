# Ejemplo 03 — Walkthrough de Red Hat Automation Hub

> Lectura y análisis **conceptual**. No requiere subscripción Red Hat ni acceso a `console.redhat.com`. Objetivo: fijar en memoria el flujo de token, los tres tiers de collections (certified / validated / community) y cuándo preferir Automation Hub sobre Galaxy público o un Pulp interno.

## 1. Qué es Automation Hub

Automation Hub es el **registry de collections** incluido con **Red Hat Ansible Automation Platform (AAP)**. Dos sabores:

- **SaaS**: `console.redhat.com/ansible/automation-hub` — hospedado por Red Hat, requiere subscripción AAP activa.
- **Private Automation Hub (PAH)**: la misma pieza instalada **on-prem** (basada en **Pulp**), espejando desde SaaS. Es la pieza para air-gap y para redes empresariales con egreso restringido.

Comparado con **Galaxy público**:

| Dimensión | Galaxy público | Automation Hub |
|-----------|----------------|-----------------|
| Coste | Gratis | Subscripción AAP (comercial) |
| Autenticación para subir | GitHub OAuth | SSO Red Hat / LDAP corporativo |
| Firma GPG de los tarballs | **No** por defecto | **Sí** (certified) |
| Soporte comercial | No | Sí (certified) |
| SLA de disponibilidad | Best-effort | Contractual |
| Uso típico | OSS, scripts, labs | Empresas reguladas, air-gap, prod serio |

## 2. Los tres tiers de contenido

En Automation Hub conviven tres categorías de collections, con contratos muy distintos:

### Certified Collections

- Mantenidas y **soportadas comercialmente** por el vendor (AWS, Cisco, F5, Microsoft, ServiceNow...).
- **Firmadas con GPG**. El cliente valida la firma antes de instalar.
- Si una collection certificada tiene un bug, abres **ticket Red Hat** y hay SLA.
- Ejemplos: `amazon.aws` (certified), `cisco.ios` (certified), `servicenow.itsm` (certified).
- Son la elección por defecto para prod en una organización con AAP.

### Validated Collections

- Probadas por Red Hat para **escenarios de referencia** (p. ej. "deploy de un cluster OpenShift con red Y en AWS").
- Menos cobertura que las certified, más opinión arquitectónica.
- Útiles cuando buscas "la forma Red Hat de hacer X".

### Community Collections (visible solo si tu Hub la trae espejada)

- Las mismas que están en Galaxy público, pero servidas desde el Hub por conveniencia de red.
- **No** firmadas ni soportadas.
- Útiles cuando una collection comunitaria cubre algo que ninguna certified cubre y quieres instalarla sin salir al Internet.

## 3. Flujo de token (conceptual)

Para que `ansible-galaxy` consuma collections desde Automation Hub, el repo necesita credenciales. El flujo típico:

```
1. Developer logeado en console.redhat.com
   → va a "Automation Hub" → "API Token"
   → clic en "Load Token"
   → copia el offline token (string largo, OIDC)

2. En su maquina local:
   export ANSIBLE_HUB_TOKEN="eyJhbGciOi..."

3. En ansible.cfg del repo (o ~/.ansible.cfg):

   [galaxy]
   server_list = automation_hub, galaxy

   [galaxy_server.automation_hub]
   url = https://console.redhat.com/api/automation-hub/
   auth_url = https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
   token = ${ANSIBLE_HUB_TOKEN}

   [galaxy_server.galaxy]
   url = https://galaxy.ansible.com/

4. ansible-galaxy collection install -r requirements.yml -p ./collections
   → busca primero en automation_hub (certified)
   → falla a galaxy (community) si no la encuentra
```

Para **Private Automation Hub** on-prem el `url` apunta a tu instancia (`https://ah.mycorp.local/api/`) y el `auth_url` suele ser el SSO interno (Keycloak corporativo, por ejemplo).

## 4. Cuándo elegir qué

| Si tu organización... | Elige |
|-----------------------|-------|
| No tiene AAP, está en Internet abierto | Galaxy público + pin exacto. |
| Tiene AAP, red abierta | Automation Hub SaaS. |
| Tiene AAP, red restringida | Private Automation Hub (on-prem) espejando SaaS. |
| No tiene AAP pero sí restricciones | Pulp interno espejando Galaxy. |
| Mezcla: AAP para prod, Galaxy para labs | `server_list` con ambos; AAP first. |

## 5. Lectura clave

1. **El token es OIDC offline**: no caduca por tiempo, pero sí es revocable. Trátalo como un secreto.
2. **La firma GPG** es la diferencia operativa más tangible entre certified y community. En producción regulada, es lo que te permite afirmar "esta collection es la que Red Hat publicó, no un paquete alterado en tránsito".
3. **PAH no es solo un espejo**: también es el destino donde una org publica **sus propias collections firmadas internamente**, y donde las políticas de aprobación corren antes de que una collection comunitaria llegue a los developers.

## 6. Preguntas de autocomprobación

1. ¿Qué distingue una collection certified de una validated?
2. ¿Puedes publicar tu `mycorp.platform` a Automation Hub SaaS? ¿Por qué sí o no?
3. Si tu red bloquea `galaxy.ansible.com`, ¿puedes seguir usando `community.general`?
4. ¿Dónde se declara el orden de búsqueda entre Automation Hub y Galaxy?
5. ¿Qué pasa si tu `ANSIBLE_HUB_TOKEN` caduca? ¿Y cómo lo rota un developer sin tocar el repo?

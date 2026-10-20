# Ejemplo 02 — GitHub Actions plugin + proxy pattern

> Lectura y walkthrough. Muestra cómo un plugin oficial descubre workflows por anotación y cómo el token GitHub **no termina en el navegador**.

## 1. Qué resuelve

El plugin de **GitHub Actions** (`@backstage-community/plugin-github-actions`) convierte el eterno badge perdido del README en un tab del `EntityPage` con:

- Lista de workflows del repo.
- Último run de cada workflow (status, duración, commit).
- Trigger manual de un workflow (si tu rol lo permite).

## 2. La anotación

```yaml
# catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-service
  annotations:
    github.com/project-slug: acme/checkout-service
spec:
  type: service
  owner: team-checkout
```

El plugin resuelve `acme/checkout-service` → `GET https://api.github.com/repos/acme/checkout-service/actions/workflows`.

## 3. ¿Cómo autentica? Dos caminos

### 3.1 OAuth del usuario (frontend-only)

Si el workspace Backstage ya tiene `auth.providers.github` configurado, el plugin usa el **token del usuario autenticado**. Nada más que hacer.

- **Ventaja:** permisos exactos del usuario (ve lo que vería en github.com).
- **Desventaja:** cada usuario necesita autorizar el app en GitHub.

### 3.2 GitHub App vía integrations (recomendado para orgs)

```yaml
# app-config.yaml
integrations:
  github:
    - host: github.com
      apps:
        - $include: github-app-credentials.yaml
```

Un **GitHub App** instalado en la org da credenciales de servicio con permisos finos (Actions: read, Metadata: read). El plugin pide tokens efímeros al backend; **el navegador no ve el PEM del App**.

## 4. Alternativa barata: `proxy.endpoints`

Si solo quieres mostrar los workflows sin usar el plugin oficial (p. ej. en una Card custom), bastaría con:

```yaml
# app-config.yaml
proxy:
  endpoints:
    '/github-actions':
      target: https://api.github.com
      headers:
        Authorization: token ${GITHUB_READ_TOKEN}
        Accept: application/vnd.github+json
```

Y desde el frontend:

```ts
const res = await fetch('/api/proxy/github-actions/repos/acme/checkout-service/actions/runs');
```

Es el patrón que el **ejemplo 03** sigue para su plugin propio: *no reinventes el plugin oficial cuando una Card con `fetch('/api/proxy/...')` resuelve el 80 % del caso.*

## 5. `EntityPage.tsx` (fragmento)

```tsx
import {
  EntityGithubActionsContent,
  isGithubActionsAvailable,
} from '@backstage-community/plugin-github-actions';

const serviceEntityPage = (
  <EntityLayout>
    <EntityLayout.Route
      path="/ci-cd"
      title="CI/CD"
      if={isGithubActionsAvailable}
    >
      <EntityGithubActionsContent />
    </EntityLayout.Route>
  </EntityLayout>
);
```

El `if={isGithubActionsAvailable}` oculta el tab si la entidad **no** tiene la anotación `github.com/project-slug`. Patrón universal (`isXxxAvailable` existe en casi todos los plugins oficiales).

## 6. Antipatterns que ver aquí

- **Token GitHub como literal en `app-config.yaml`** → termina en el bundle. Usa `${...}` siempre.
- **PAT personal del CTO** como token de integración → cuando el CTO se va, todo el portal rompe. Usa GitHub App.
- **Instalar el plugin sin configurar `integrations`** → el plugin cae a OAuth del usuario, lo que puede estar bien pero debe ser una decisión consciente.

## 7. Siguiente

El ejemplo 03 cierra el ciclo: cómo luce el **esqueleto** del plugin propio que harás en la actividad 02.

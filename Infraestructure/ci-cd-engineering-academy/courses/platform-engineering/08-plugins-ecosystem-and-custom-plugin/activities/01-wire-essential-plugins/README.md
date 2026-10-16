# Actividad 01 — Cablear 3 plugins esenciales en Backstage

## 1. Identificación

- **ID:** `plat-08-01-wire-essential-plugins`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-08-plugins-ecosystem-and-custom-plugin`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Acabas de instalar un Backstage limpio en tu organización. Hay 40 servicios en el catálogo. Developers abren tickets diciendo *"esto es solo un wiki, no me ayuda a operar"*. Tienes que decidir **qué 3 plugins instalar primero** para que el portal pase de "wiki tipado" a "portal operativo útil".

La actividad **no exige** levantar Backstage ni un cluster. Es un trabajo de **cableado documental**: eliges los plugins, escribes los fragmentos de configuración (`app-config.yaml`), las anotaciones de catálogo (`catalog-info.yaml`) y la integración en el `EntityPage.tsx`. Un junior debería poder seguir tu `WIRING.md` y aplicarlo sin leer la lección.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar 3 plugins oficiales que juntos cubran **"¿funciona?" / "¿compila?" / "¿deployó?"**.
- Escribir el fragmento `kubernetes:` de `app-config.yaml` sin inventar campos.
- Enumerar las anotaciones well-known para los 3 plugins.
- Decidir, para cada plugin, si autentica con **OAuth del usuario**, **GitHub App / Service Account** o **proxy con token de servicio**, y justificar.
- Explicar en 1 párrafo por qué cada plugin aporta antes que las alternativas.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los 3 `examples/` del módulo.
- Prerrequisitos del módulo: `plat-04`, `plat-05`.
- Herramientas: `bash` y un editor Markdown. **No** se requiere Node, Yarn ni cluster.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-08-wiring
cd /tmp/plat-08-wiring
```

Puedes usar otra ruta, pero entonces pásala al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `WIRING.md` con cinco secciones

#### Sección A — Elección y justificación

Lista los **3 plugins** elegidos, en el **orden** en que los instalarías. Para cada uno, 2–3 líneas: qué pregunta operativa resuelve y por qué va antes que el siguiente.

Candidatos razonables:

- `kubernetes`, `github-actions`, `argo-cd`, `pagerduty`, `grafana`, `tech-insights`, `cost-insights`, `sonarqube`, `sentry`, `datadog`.

Al menos **uno** de los 3 debe ser `kubernetes` **o** `github-actions` **o** `argo-cd` (los validadores comprueban que menciones estas tres familias en algún punto del documento).

#### Sección B — Configuración (`app-config.yaml`)

Un **bloque de código** por plugin, con las claves obligatorias. Usa `${VAR_NAME}` para cualquier secreto. Mínimo esperado:

- Bloque `kubernetes:` con `clusterLocatorMethods` o equivalente.
- Bloque `integrations:` o `proxy:` para GitHub Actions.
- Bloque de Argo CD, PagerDuty, Grafana o similar según los que elegiste.

#### Sección C — Anotaciones de catálogo (`catalog-info.yaml`)

Un fragmento **único** de `catalog-info.yaml` que combine las anotaciones well-known de los 3 plugins:

```yaml
# ejemplo (no copies literal, adaptalo)
metadata:
  annotations:
    backstage.io/kubernetes-id: ...
    github.com/project-slug: ...
    argocd/app-name: ...
```

Al menos **3 anotaciones** distintas deben aparecer.

#### Sección D — `EntityPage.tsx`

Fragmento JSX con los `EntityLayout.Route` para los 3 plugins (puedes usar `if={isXxxAvailable}` donde aplique).

#### Sección E — Decisión de auth por plugin

Tabla (3 filas):

```
| Plugin | Modo de auth | Por que |
```

Modos válidos: `oauth-usuario`, `service-account`, `github-app`, `proxy-token`.

### 5.3 Entregable

Un archivo:

```
/tmp/plat-08-wiring/WIRING.md
```

con las cinco secciones A, B, C, D, E.

## 6. Resultado esperado

- `WIRING.md` existe.
- Contiene las 5 secciones.
- Nombra **al menos** `kubernetes`, `github-actions` y `argo-cd` en algún lugar del documento (aunque hayas elegido 3 distintos como "top 3", debes al menos citarlos para justificar por qué no los elegiste).
- Al menos **3 bloques de código** (` ``` `).
- Al menos **3 anotaciones** `backstage.io/*` o `github.com/*` o `argocd/*` o `pagerduty.com/*` o `grafana/*`.
- Menciona `proxy` y `discoveryApi` o equivalente operacional.
- `bash tests/validate.sh /tmp/plat-08-wiring` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada plugin tiene config + anotación + tab coherentes entre sí.
- **Reproducibilidad**: alguien que lea tu documento puede aplicar los fragmentos a un Backstage real.
- **Mantenibilidad**: Markdown válido, bloques de código con lenguaje declarado (` ```yaml`, ` ```tsx`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-08-wiring
```

El validador comprueba **estructura**, no semántica. Compara tu documento con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si tu organización no usa Argo CD, ¿cuál es el 3º plugin que elegirías y por qué?
2. ¿Qué pierdes si en lugar del plugin oficial de GitHub Actions usas una Card custom con `proxy.endpoints`?
3. ¿Por qué el plugin de Kubernetes necesita una **ServiceAccount** y no basta con OAuth de usuario?
4. ¿Qué deuda técnica introduces si pineas los plugins a versiones antiguas del core?
5. ¿En qué momento tiene sentido fork-ear un plugin oficial? (Pista: casi nunca.)

## 10. Extensiones

- Añade una sexta sección "F — Checklist de verificación post-instalación" (3–5 pasos para comprobar que los 3 plugins responden).
- Dibuja un diagrama ASCII mostrando el flujo `browser → backstage backend → proxy → sistema externo` para uno de los plugins.
- Propón un ADR corto: *"Instalar plugins oficiales vs comunitarios"*.

## 11. Limpieza

```bash
rm -rf /tmp/plat-08-wiring
```

No hay procesos ni contenedores que detener.

# Actividad 01 — Instalar Helm y explorar charts del ecosistema

## 1. Identificación

- **ID:** `helm-01-01-install-helm-and-explore`
- **Tecnología:** `helm`
- **Módulo:** `helm-01-mental-model-and-setup`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** guided-lab

## 2. Contexto

Antes de instalar nada en un cluster, necesitas:

1. **El binario `helm`** en tu máquina (es un solo ejecutable, Go, sin daemon).
2. Saber dónde Helm guarda su configuración y su cache (`helm env`).
3. Saber **buscar** charts (en Artifact Hub o en repos añadidos localmente) y **leerlos** antes de pensar en instalarlos.

Esta actividad construye ese setup y te deja un `NOTES.md` que es tu propia memoria del entorno.

## 3. Objetivos

Al terminar deberías poder:

- Instalar `helm` y verificar que `helm version` corre.
- Enumerar las variables de entorno de Helm (`helm env`) y saber qué significa cada una.
- Añadir un chart repository HTTP (`helm repo add`) y actualizarlo (`helm repo update`).
- Buscar charts en Artifact Hub (`helm search hub`) y en repos locales (`helm search repo`).
- Imprimir metadata (`helm show chart`) y defaults de values (`helm show values`) de un chart popular.
- Documentar todo en un `NOTES.md` reproducible.

## 4. Prerrequisitos

- Sistema operativo: macOS, Linux o WSL en Windows.
- `bash` disponible.
- Conexión a Internet (para instalar `helm` y consultar Artifact Hub).
- Permisos para instalar un binario local (vía `brew`, `apt`, `curl`, etc.).

**Costos**: ninguno (todo es local y lectura de red pública).

**Si no tienes `helm` y no puedes instalarlo**, la actividad se puede completar documentando la **ausencia** y las instrucciones de instalación en el `NOTES.md` — el validador detecta el caso y lo informa.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/helm-01-explore
cd /tmp/helm-01-explore
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`.)

### 5.2 Instalar `helm`

Elige **una** opción según tu sistema:

- **macOS (Homebrew)**:
  ```bash
  brew install helm
  ```
- **Linux (script oficial)**:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ```
- **Linux (apt / Debian/Ubuntu)**:
  ```bash
  curl https://baltocdn.com/helm/signing.asc | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt update && sudo apt install helm
  ```
- **Binario manual** (cualquier sistema): descarga desde <https://github.com/helm/helm/releases> y coloca `helm` en tu `PATH`.

Verifica:

```bash
helm version
```

Debería imprimir algo como:

```
version.BuildInfo{Version:"v3.14.0", GitCommit:"...", GitTreeState:"clean", GoVersion:"go1.21.5"}
```

**Si falla con "command not found"**, repite la instalación o ajusta el `PATH`.

### 5.3 Inspeccionar el entorno

```bash
helm env
```

Captura la salida completa; la necesitarás en `NOTES.md`. Observa en particular:

- `HELM_CACHE_HOME` — donde Helm cachea charts descargados.
- `HELM_CONFIG_HOME` — donde vive `repositories.yaml`.
- `HELM_DATA_HOME` — datos auxiliares.
- `HELM_REPOSITORY_CONFIG` — ruta exacta del archivo con tus repos.
- `HELM_REPOSITORY_CACHE` — cache del `index.yaml` de cada repo.

### 5.4 Añadir un repo HTTP y refrescar

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm repo list
```

### 5.5 Buscar en Artifact Hub (red)

```bash
helm search hub ingress-nginx --max-col-width 60 | head -5
helm search hub cert-manager  --max-col-width 60 | head -5
helm search hub prometheus    --max-col-width 60 | head -5
```

### 5.6 Buscar en los repos locales

```bash
helm search repo ingress-nginx
helm search repo ingress-nginx --versions | head -5
```

### 5.7 Inspeccionar un chart sin instalarlo

```bash
helm show chart   ingress-nginx/ingress-nginx > chart-metadata.yaml
helm show values  ingress-nginx/ingress-nginx > chart-values.yaml
helm show readme  ingress-nginx/ingress-nginx > chart-readme.md
wc -l chart-metadata.yaml chart-values.yaml chart-readme.md
```

### 5.8 Entregable: `NOTES.md`

Crea `NOTES.md` en `/tmp/helm-01-explore/` con estas **secciones obligatorias** (titula con `##`):

#### Secciones

1. **`## Helm version`** — pega la salida de `helm version`.
2. **`## Helm env`** — pega la salida de `helm env`. Añade un párrafo explicando qué es `HELM_REPOSITORY_CONFIG` y por qué importa.
3. **`## Repository añadido`** — comando usado para añadir `ingress-nginx` y la salida de `helm repo list`.
4. **`## Charts encontrados en Artifact Hub`** — lista de **al menos 5 charts** encontrados con `helm search hub` (de las búsquedas de 5.5 u otras que hagas). Para cada chart: nombre, URL de Artifact Hub, versión del chart, versión del app, una línea de descripción.
5. **`## Metadata del chart ingress-nginx`** — fragmento de `chart-metadata.yaml`. Resalta `version` (chart) vs `appVersion` (nginx).
6. **`## values.yaml como API`** — en 3–5 frases, explica con tus palabras por qué `values.yaml` es la API del chart. Da **dos ejemplos concretos** de knobs que viste en `chart-values.yaml` (p. ej. `controller.replicaCount`, `controller.service.type`).
7. **`## Conclusión`** — una frase que resuma tu entorno y tu primera impresión del flujo exploratorio.

### 5.9 Validar estructura

```bash
bash tests/validate.sh /tmp/helm-01-explore
```

El validador comprueba que `NOTES.md` exista y mencione los conceptos obligatorios (version, env, repo, search hub, show chart, show values, values como API, al menos 5 referencias a charts). **No valida contenido semántico** — compara tus respuestas con `solution/SOLUTION.md`.

**Si no tenías `helm` instalado**, el validador detecta la ausencia (via grep al propio `NOTES.md`) y acepta el fallback documentado — ver §7.

## 6. Resultado esperado

- `helm version` corre y la versión está documentada.
- `/tmp/helm-01-explore/NOTES.md` existe con las 7 secciones.
- `/tmp/helm-01-explore/chart-metadata.yaml`, `chart-values.yaml`, `chart-readme.md` existen.
- `tests/validate.sh` pasa (estructural).

## 7. Criterios de aceptación

- [ ] `NOTES.md` tiene las **7 secciones** con los encabezados exactos (`## Helm version`, `## Helm env`, …).
- [ ] `NOTES.md` menciona `HELM_REPOSITORY_CONFIG` con explicación.
- [ ] `NOTES.md` lista al menos **5 charts** distintos encontrados en Artifact Hub.
- [ ] `NOTES.md` distingue `version` (del chart) de `appVersion` (del software).
- [ ] `NOTES.md` justifica por qué `values.yaml` es la API del chart con **dos ejemplos concretos**.
- [ ] Si `helm` no está instalado, `NOTES.md` incluye las instrucciones de instalación (`brew install helm` u otra) y el validador lo acepta como fallback documentado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/helm-01-explore
```

Estructural. **Semántica la calibras tú** con `solution/SOLUTION.md`.

## 9. Preguntas de reflexión

Más allá de completar el entregable:

1. ¿Por qué `helm search hub` no requiere `helm repo add` y `helm search repo` sí? ¿Qué consulta cada uno?
2. ¿Qué pasaría si borras `~/Library/Preferences/helm/repositories.yaml` (macOS) o `~/.config/helm/repositories.yaml` (Linux)?
3. En el `values.yaml` de `ingress-nginx`, encuentra 3 ejemplos de valores que tú sí tocarías en producción y 3 que probablemente **no**. Justifica.
4. Si Artifact Hub se cayera, ¿`helm search repo` seguiría funcionando? ¿Y `helm show values`? ¿Por qué?

## 10. Extensiones (opcional)

- **E1** — Añade un segundo repo (`helm repo add jetstack https://charts.jetstack.io`) y repite `helm show chart` + `helm show values` sobre `jetstack/cert-manager`.
- **E2** — Explora `helm search hub` con `--list-repo-url` para ver todos los repos distintos donde aparece "prometheus" como keyword. Observa la fragmentación del ecosistema.
- **E3** — Usa `helm pull ingress-nginx/ingress-nginx --version <v> --untar` para bajarte el chart entero a disco y explora su estructura (`Chart.yaml`, `templates/`, `charts/` si tuviera deps). Esto es `helm-03` adelantado.

## 11. Limpieza

```bash
rm -rf /tmp/helm-01-explore
# Opcional: quitar el repo añadido si no lo quieres mantener.
# helm repo remove ingress-nginx
```

# Actividad 01 — Adoptar collections comunitarias y empaquetar una propia

## 1. Identificación

- **ID:** `ans-05-01-adopt-community-aws-collection`
- **Tecnología:** `ansible`
- **Módulo:** `ans-05-collections-galaxy-and-automation-hub`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a montar el esqueleto de dependencias de collections que usará el repo de **plataforma interna** de tu organización. Dos piezas:

- Un **`collections/requirements.yml`** que declara 3 collections externas pineadas (una certified `amazon.aws`, una comunitaria `community.general`, una POSIX `ansible.posix`).
- Una **collection propia** `mycorp.platform` inicializada con `ansible-galaxy collection init`, con `galaxy.yml` real (versión, authors, license, dependencies, repository) y la estructura mínima (`plugins/`, `roles/`, `playbooks/`, `meta/runtime.yml`).

Ambas conviven en el mismo directorio de trabajo. Si tienes red, además instalas las 3 collections externas en `./collections/` y verificas con `ansible-galaxy collection list`. Si estás **offline**, saltas ese paso: el validador no lo exige.

**Importante**: no se publica nada a Galaxy ni a Automation Hub. Es un ejercicio de **estructura** y **manifiesto**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir un `requirements.yml` de collections con pin por versión y uno con rango acotado.
- Inicializar una collection propia y rellenar `galaxy.yml` con los campos que Galaxy / Automation Hub requieren para aceptar un upload.
- Explicar por qué el `./collections` del repo se añade a `.gitignore` (contenido) pero el `collections/requirements.yml` y la collection propia **sí** se versionan.
- Dejar documentado el intent de cada collection declarada (qué uso, por qué ese pin, qué pasa si no se cumple).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido `../../examples/01-requirements-yml-with-collections/` y `../../examples/02-create-and-publish-collection/`.
- Herramientas: `bash`, `python3`, un editor de texto. **Opcional**: `ansible-core >= 2.17` (`pipx install ansible-core`) para correr `ansible-galaxy collection install` localmente. Si no tienes `ansible-galaxy` instalado o estás offline, la actividad se completa igual (sin ese paso).

**Costos**: ninguno. Todo local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-05-01
cd /tmp/ans-05-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `collections/requirements.yml`

Crea el archivo `/tmp/ans-05-01/collections/requirements.yml` con **al menos 3 collections externas**:

- `amazon.aws` con pin exacto a una versión real (p. ej. `"8.2.0"`).
- `community.general` con pin exacto (p. ej. `"9.4.0"`).
- `ansible.posix` con pin exacto (p. ej. `"1.5.4"`).

Puedes añadir más. Cada entrada debe tener los campos `name`, `version` y `source` (apuntando a `https://galaxy.ansible.com`).

### 5.3 Inicializa la collection propia

Dentro de `/tmp/ans-05-01/`, crea una collection `mycorp.platform` con la estructura mínima:

```
/tmp/ans-05-01/mycorp/platform/
├── galaxy.yml
├── README.md
├── meta/
│   └── runtime.yml
├── plugins/
│   └── modules/
├── roles/
└── playbooks/
```

Si tienes `ansible-galaxy` instalado:

```bash
cd /tmp/ans-05-01
ansible-galaxy collection init mycorp.platform
```

(Reorganiza si el init la deja bajo `./mycorp/platform/` — es el layout canónico.)

Si **no** tienes `ansible-galaxy`, crea los directorios y archivos a mano. El validador no exige nada que `ansible-galaxy init` haga especial más allá de la estructura y `galaxy.yml` válido.

### 5.4 Rellena `galaxy.yml`

El `galaxy.yml` de tu collection debe tener **al menos** estos campos (todos obligatorios para que Galaxy acepte un upload):

- `namespace: mycorp`
- `name: platform`
- `version: 1.0.0` (semver)
- `readme: README.md`
- `authors:` lista con al menos 1 autor
- `description:` string no vacío
- `license:` lista con al menos una licencia (`Apache-2.0`, `MIT`, `GPL-3.0-or-later`...)
- `tags:` lista con al menos 2 tags
- `dependencies:` mapa de collection → rango de versiones (puede ser vacío `{}` si no tiene dependencias, pero debe estar la clave)
- `repository:` URL
- `issues:` URL

### 5.5 Rellena `meta/runtime.yml`

Mínimo:

```yaml
---
requires_ansible: ">=2.17.0"
```

### 5.6 Escribe `README.md` del repo

Crea `/tmp/ans-05-01/README.md` que explique:

- Qué collections declara el repo y por qué (una sección por collection externa).
- Por qué el pin elegido (exacto vs rango).
- Qué hace la collection propia `mycorp.platform` a alto nivel.
- Cómo instalar: comando `ansible-galaxy collection install -r collections/requirements.yml -p ./collections`.

Secciones obligatorias que el validador busca (sintaxis `## ...`):

- `## Collections externas`
- `## Collection propia mycorp.platform`
- `## Instalacion` (o `## Instalación`)

### 5.7 (Opcional, requiere red) Instala y verifica

```bash
cd /tmp/ans-05-01
ansible-galaxy collection install -r collections/requirements.yml -p ./collections --force
ansible-galaxy collection list -p ./collections
```

Deberías ver `amazon.aws`, `community.general` y `ansible.posix` listadas con sus versiones. Si estás offline, salta este paso: el validador lo marca como `SKIP` y no falla.

### 5.8 Entregables

```
/tmp/ans-05-01/
├── README.md
├── collections/
│   └── requirements.yml
└── mycorp/
    └── platform/
        ├── galaxy.yml
        ├── README.md
        ├── meta/
        │   └── runtime.yml
        ├── plugins/
        │   └── modules/
        ├── roles/
        └── playbooks/
```

## 6. Resultado esperado

- Validador en verde: estructura presente, `requirements.yml` parsea como YAML y declara al menos 3 collections con `name` + `version` + `source`, `galaxy.yml` parsea como YAML y tiene los campos obligatorios con valores válidos, `README.md` del repo tiene las 3 secciones.
- Si hay red: `ansible-galaxy collection list -p ./collections` muestra las 3 collections externas.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud**: pins coherentes con lo que la lección recomienda (exacto para prod).
- **Mantenibilidad**: `galaxy.yml` ordenado, `README.md` del repo claro, intent documentado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-05-01
```

El validador comprueba estructura y campos obligatorios. **No** publica la collection ni consulta Galaxy.

## 9. Preguntas de reflexión

1. Si en 3 meses `amazon.aws 8.3.0` publica un fix crítico para `s3_object`, ¿qué cambias en el repo?
2. ¿Por qué `requirements.yml` vive bajo `collections/` y no en la raíz?
3. Si tu organización pasa a tener Private Automation Hub, ¿qué cambia en `requirements.yml`?
4. ¿Qué pasa si subes `mycorp.platform 1.0.0` dos veces a Galaxy?
5. ¿Cuándo subirías la versión a `2.0.0` vs `1.1.0`?

## 10. Extensiones

- Añade una **cuarta** collection declarada por git (`type: git` + `source` + `version: v1.0.0`).
- Añade un `requirements.lock.yml` capturado tras `collection list`.
- Añade un `ansible.cfg` que fije `collections_path = ./collections`.

## 11. Limpieza

```bash
rm -rf /tmp/ans-05-01
```

No hay infraestructura que detener.

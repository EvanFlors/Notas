# Ejemplo 01 — `requirements.yml` con collections pineadas

> Lectura y análisis. Objetivo: entender campo a campo cómo se declara una dependencia de collection, cómo mezclar Galaxy público con un repo git privado y cómo justificar los pins.

## 1. El archivo

```yaml
---
# collections/requirements.yml
#
# Dependencias de collections del repo. Pin exacto en prod; rango en librerías.
# Instala con:
#   ansible-galaxy collection install -r collections/requirements.yml \
#     -p ./collections --force
#
# El flag --force refresca la instalacion local sin tocar ~/.ansible.

collections:
  # Modulos AWS oficiales (certified). Pin exacto: la migracion de 7.x -> 8.x
  # renombro parametros de ec2_vpc_net.
  - name: amazon.aws
    version: "8.2.0"
    source: https://galaxy.ansible.com

  # Modulos AWS comunitarios (lo que amazon.aws no cubre).
  # Rango permitido porque usamos solo s3_lifecycle, estable.
  - name: community.aws
    version: ">=8.0.0,<9.0.0"
    source: https://galaxy.ansible.com

  # Utilidades POSIX (sysctl, mount, firewalld, authorized_key).
  - name: ansible.posix
    version: "1.5.4"
    source: https://galaxy.ansible.com

  # Collection interna de la organizacion, hospedada en GitLab privado.
  # Pin por tag git para auditoria.
  - name: mycorp.platform
    source: https://gitlab.mycorp.local/platform/ansible-collection-platform.git
    type: git
    version: v1.4.2
```

## 2. Lectura clave

1. **Pin exacto para `amazon.aws`**. Las migraciones mayores (7→8, 8→9) renombran parámetros; un rango abierto rompe el día de la release.
2. **Rango acotado para `community.aws`**. Si solo usas módulos estables de la collection y confías en semver, un rango `>=8.0.0,<9.0.0` recibe parches pero evita la breaking.
3. **Pin a `ansible.posix 1.5.4`**. Las utilidades POSIX cambian poco; aun así, pin exacto es la elección segura.
4. **`mycorp.platform` por git + tag**. El `source` apunta a GitLab privado; el `version: v1.4.2` es un **tag anotado**, no un commit SHA (más legible). Para máxima inmutabilidad, usar el SHA completo.

## 3. Resolución y lockfile

Tras `ansible-galaxy collection install -r collections/requirements.yml -p ./collections`, puedes capturar las versiones resueltas:

```bash
ansible-galaxy collection list --format yaml > collections/requirements.lock.yml
```

Y en CI usas la lock:

```bash
ansible-galaxy collection install -r collections/requirements.lock.yml -p ./collections
```

## 4. Qué NO está en el archivo

- Collections traídas por dependencia transitiva (p. ej. `community.aws` depende de `amazon.aws`). `ansible-galaxy` las resuelve, pero conviene **declarar explícitamente** las que usas, para que un `grep` en el repo las encuentre.
- Roles sueltos (fuera de collections). Esos van en una sección aparte `roles:` del mismo `requirements.yml` o en un archivo separado. Hoy el patrón moderno es empaquetar roles **dentro de una collection propia**.

## 5. Preguntas de autocomprobación

1. ¿Qué pasa si `community.aws` publica `9.0.0` con la breaking? El rango `<9.0.0` lo evita.
2. ¿Dónde debería vivir físicamente el directorio `./collections` en el repo? ¿Se commitea?
3. Si quiero probar un **commit sin release** de `amazon.aws`, ¿cómo cambia la entrada? (Pista: `type: git` + `source` + `version: <SHA>`.)
4. ¿Qué comando listar las collections instaladas con sus versiones exactas?
5. ¿Por qué `ansible.builtin` **no** aparece en `requirements.yml`?

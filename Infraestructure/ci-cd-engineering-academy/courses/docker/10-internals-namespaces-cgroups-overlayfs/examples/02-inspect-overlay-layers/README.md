# Ejemplo 02 — Inspección de capas overlayfs

## Concepto que demuestra

Qué son `lowerdir`, `upperdir`, `merged` y `workdir` **en el filesystem real** del host, y qué pasa en cada uno al leer, escribir y borrar archivos dentro del contenedor.

## Plataforma

**Linux-only.** En macOS/Windows: `multipass shell <vm>` o `vagrant ssh` y ejecutar dentro.
En Docker Desktop (macOS) `/var/lib/docker/overlay2/` vive dentro de la VM del Desktop, no accesible desde el finder.

## Prerrequisitos

- Docker Engine con storage driver `overlay2` (verifica con `docker info | grep -i 'storage driver'`).
- Permisos de root para leer `/var/lib/docker/overlay2/`.

## Ejecución

```bash
# 1. Levantar un contenedor y pedir su graph driver
docker run -d --name overlay-demo nginx:alpine
docker inspect overlay-demo --format '{{json .GraphDriver}}' | jq
```

Salida esperada (resumida):

```json
{
  "Data": {
    "LowerDir": "/var/lib/docker/overlay2/<L3>/diff:/var/lib/docker/overlay2/<L2>/diff:/var/lib/docker/overlay2/<L1>/diff",
    "MergedDir": "/var/lib/docker/overlay2/<C>/merged",
    "UpperDir":  "/var/lib/docker/overlay2/<C>/diff",
    "WorkDir":   "/var/lib/docker/overlay2/<C>/work"
  },
  "Name": "overlay2"
}
```

### Diagrama mental

```
                merged/                 (lo que el contenedor ve como "/")
                 /  \
                /    \   lookup top-down
               /      \
            upper/    L1/ : L2/ : L3/
             (RW)      ^-- lower chain, read-only
```

### Explorar

```bash
# 2. Guardar paths
MERGED=$(docker inspect overlay-demo --format '{{.GraphDriver.Data.MergedDir}}')
UPPER=$(docker inspect  overlay-demo --format '{{.GraphDriver.Data.UpperDir}}')
LOWER=$(docker inspect  overlay-demo --format '{{.GraphDriver.Data.LowerDir}}')

# 3. Qué hay inicialmente en upper (debería estar casi vacío — el contenedor acaba de arrancar)
sudo ls -la "$UPPER"

# 4. Qué hay en merged (es el rootfs del contenedor "desde fuera")
sudo ls "$MERGED" | head

# 5. Qué hay en cada lower (son las capas de la imagen)
echo "$LOWER" | tr ':' '\n'
```

### Observar copy-up

```bash
# 6. Escribir un archivo nuevo dentro del contenedor
docker exec overlay-demo sh -c 'echo "hola" > /etc/nuevo.txt'
sudo find "$UPPER/etc" -maxdepth 1 -type f
# Debe listar /var/lib/docker/overlay2/<C>/diff/etc/nuevo.txt

# 7. Modificar un archivo que SOLO existía en un lower
docker exec overlay-demo sh -c 'echo "# modificado" >> /etc/nginx/nginx.conf'
# El archivo fue copy-up al upper
sudo ls "$UPPER/etc/nginx/nginx.conf"
# Y el lower original sigue intacto
sudo find "$(echo "$LOWER" | cut -d: -f1)/etc/nginx/" -maxdepth 1 -name nginx.conf

# 8. Borrar un archivo del lower → whiteout
docker exec overlay-demo rm /etc/hostname
# Veremos un char device 0:0 en upper que oculta el lower
sudo ls -la "$UPPER/etc/hostname"
# c--------- 1 root root 0, 0 ... hostname
```

### Simular overlayfs a mano (opcional)

```bash
sudo mkdir -p /tmp/ov/{lower1,lower2,upper,work,merged}
echo "A desde lower1" | sudo tee /tmp/ov/lower1/a.txt
echo "B desde lower2" | sudo tee /tmp/ov/lower2/b.txt
echo "A desde lower2 (gana el 1)" | sudo tee /tmp/ov/lower2/a.txt

sudo mount -t overlay overlay \
  -o lowerdir=/tmp/ov/lower1:/tmp/ov/lower2,upperdir=/tmp/ov/upper,workdir=/tmp/ov/work \
  /tmp/ov/merged

cat /tmp/ov/merged/a.txt   # "A desde lower1"  (lower1 gana por orden)
cat /tmp/ov/merged/b.txt   # "B desde lower2"
echo "nuevo" > /tmp/ov/merged/c.txt
sudo ls /tmp/ov/upper      # c.txt (fue a parar al upper)

sudo umount /tmp/ov/merged
sudo rm -rf /tmp/ov
```

## Resultado esperado

- Puedes señalar en disco qué archivo del contenedor vive en qué capa.
- Entiendes que una modificación de un archivo de la imagen produce **duplicación**: el original queda en el lower, la versión modificada en el upper.
- Entiendes el whiteout como un char device 0:0.

## Interpretación

- Los `lower` son `diff/` de capas de la imagen OCI. Son **compartidos** por todos los contenedores que usen esa imagen (ahorro de disco).
- El `upper` y `work` son únicos del contenedor y se destruyen al eliminarlo (`docker rm`). Por eso **nunca** persistas datos en el rootfs — usa volúmenes.

## Errores frecuentes

- **"Permission denied" al leer `/var/lib/docker/`** → necesitas `sudo`.
- **`GraphDriver.Name = aufs|devicemapper|btrfs`** → tu daemon no usa overlay2. Hoy es raro.
- **En Docker Desktop macOS** no ves los paths porque viven en la VM del Desktop.

## Limpieza

```bash
docker rm -f overlay-demo
```

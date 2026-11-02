# Ejemplo 01 — Iteración: bueno vs. malo

Dos scripts resuelven **la misma tarea** ("listar y contar los archivos del directorio") de dos formas: una incorrecta (`bad-iter.sh`, parsea `ls`) y una correcta (`good-iter.sh`, usa un glob).

## Objetivo didáctico

Ver con los propios ojos la diferencia entre ambos patrones ante nombres hostiles.

## Ejecución

```bash
cd files/
bash setup-fixture.sh         # crea un directorio ./fixture con nombres hostiles
bash bad-iter.sh  ./fixture   # observa: pierde archivos, cuenta mal, expande globs
bash good-iter.sh ./fixture   # observa: todos los archivos aparecen una vez
```

## Qué observar

- `bad-iter.sh` imprime fragmentos (`foo` y `bar.txt` por separado para `foo bar.txt`).
- `bad-iter.sh` imprime los `.sh` del CWD cuando encuentra el archivo literal `*.sh` (glob expansion).
- `bad-iter.sh` reporta un conteo erróneo.
- `good-iter.sh` imprime exactamente los archivos presentes, cada uno una vez, y cuenta correctamente.

## Limpieza

```bash
rm -rf files/fixture
```

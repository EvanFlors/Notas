# Respuestas de referencia — scavenger hunt

## P1
- comando usado: `whatis fstab` → `fstab (5)`; o directamente `man 5 fstab`.
- respuesta: **5** (formatos de archivo).

## P2
- comando usado: `man 1 grep` → `/^ *-l` para localizar el flag.
- respuesta: **`-l`** (`--files-with-matches`). Complemento `-L` lista los que *no* contienen.

## P3
- comando usado: `man 1 tar` → `/--directory`.
- respuesta: **`--directory=DIR`** (equivalente larga de `-C DIR`).

## P4
- comando usado: `man 1 ls` → `/ENVIRONMENT`.
- respuesta: **`LC_COLLATE`** (y en su defecto `LANG`/`LC_ALL`). `LC_COLLATE` es la que gobierna el orden de clasificación por locale.

## P5
- comando usado: `man 1 curl` → `/EXIT CODES` → `/22`.
- respuesta: **22** (`HTTP page not retrieved`, se activa con `-f`/`--fail`).

## P6
- comando usado: `man 1 find` → `/-mtime`.
- respuesta: **`-mtime -1`** (modificado hace menos de 1 día).

## P7
- comando usado: `man 5 ssh_config` → `/IdentityFile`.
- respuesta: **`IdentityFile`** (p. ej. `IdentityFile ~/.ssh/id_ed25519`).

## P8
- comando usado: `man 5 systemd.service` → `/ExecStart`.
- respuesta: **`ExecStart=`**.

## P9
- comando usado: `man 1 rsync` → `/-a,`.
- respuesta: **`-a`** (`--archive`, equivalente a `-rlptgoD`).

## P10
- comando usado: `man 7 signal` → `/SIGKILL`.
- respuesta: **9** (en Linux x86/x86_64/arm64, por convención histórica POSIX).

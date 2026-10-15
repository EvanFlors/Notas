# Actividad 02 — Collaboration simulation: Alice + Bob + one bare

## 1. Identificación

- **ID:** `gh-04-02-collab-simulation-two-clones`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-04-remotes-and-collaboration-basics`
- **Dificultad:** intermediate
- **Duración estimada:** 50 min
- **Tipo:** independent

## 2. Contexto

Dos personas, un repo compartido, cero GitHub. Vas a reproducir la vida real: alguien pushea, el otro queda atrás; el otro intenta pushear sin fetchear primero y recibe un `non-fast-forward`; la ruta correcta es `fetch` → `rebase` → `push`.

El validador comprueba el **estado final** del escenario, no tu secuencia exacta de comandos.

**No consultes `solution/` hasta terminar.**

## 3. Objetivos

Al terminar deberías poder:

- Operar dos clones contra un mismo bare remote.
- Interpretar `(non-fast-forward)` y resolverlo **sin** `--force`.
- Dejar los dos clones y el bare sincronizados en la misma punta.
- Entender que `rebase` reescribe hashes y aún así todo converge.

## 4. Prerrequisitos

- `gh-04-01-local-bare-remote` completada.
- Haber reproducido `examples/01-fetch-vs-pull/` y `examples/02-two-clones-same-repo/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-base.sh /tmp/gh-04-collab
```

Esto crea:

```
/tmp/gh-04-collab/
├── origin.git/      bare "server" con un commit "init: project"
├── alice/           clone configurado como Alice (user.name=Alice)
└── bob/             clone configurado como Bob   (user.name=Bob)
```

Ambos clones ya tienen `origin` apuntando al bare y `main` tracking `origin/main`.

### 5.2 La misión

Produce un estado final que cumpla **todas** estas condiciones:

1. En **`origin.git` main** existen (al menos) estos 3 commits además del `init: project`, en algún orden lineal (sin merge commits):
   - `feat(alice): add alice.md`
   - `feat(alice): add second alice feature`
   - `feat(bob): add bob.md`
2. `origin.git` tiene **exactamente** `main` como rama (no debe haber ramas extras pusheadas desde ningún clon).
3. `main` en `alice/`, `bob/` y `origin.git/` apuntan al **mismo commit**.
4. En `bob/` **`refs/remotes/origin/main`** coincide con `bare/main` (es decir, bob fetcheó al final).
5. En `alice/` igualmente **`refs/remotes/origin/main`** coincide con `bare/main`.
6. La historia de `main` en el bare NO contiene merge commits (es lineal). Esta regla fuerza a usar `rebase` para integrar en vez de `pull` default.
7. **No hay force push a `main`**: todos los commits reales acabaron en el server. (No puedes "haber borrado" `feat(alice): add alice.md` del server y volverlo a pushear con otro hash — tiene que existir ese commit en la historia alcanzable, aunque el commit de bob fue rebasado).

Pistas de ritmo:
- Alice pushea `alice.md` primero.
- Bob clona (ya está hecho) y pushea `bob.md` antes de que Alice pushee su segundo commit → push de Bob va bien.
- Alice intenta pushear su **segundo** feat → ¿fast-forward o rechazo? (depende de si fetcheó).
- Haz que el rechazo ocurra. Fuérzalo si es necesario (ambos trabajan sin fetchear entre pushes).
- Luego resuélvelo con `fetch` + `rebase`.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/gh-04-collab
```

Debería terminar en `RESULT: 7/7 checks OK.`

### 5.4 Pistas (en orden de "escalada")

Si te atascas:

**Para generar el rechazo**:
- Pista 1: Ambos deben hacer commit local antes de pushear.
- Pista 2: El primero que pushea gana. El segundo recibe `(non-fast-forward)`.
- Pista 3: `fetch` + `rebase origin/main` + `push`.

**Para asegurar historia lineal**:
- Pista 1: `git log --graph --oneline main` en el bare debe mostrar una línea recta, sin asteriscos con bifurcación.
- Pista 2: Nunca uses `git merge origin/main` para integrar; usa `git rebase origin/main`.
- Pista 3: Si acabas con un merge commit, `git reset --hard HEAD~1` y rebasa.

**Para evitar que valide "ramas extras"**:
- Pista 1: Si creaste alguna rama local como `feature/x` y la pusheaste con `-u`, bórrala en el server con `git push --delete origin feature/x`.
- Pista 2: `git ls-remote --heads origin` debe mostrar **solo** `main`.

## 6. Resultado esperado

- Los 3 commits de feature + el init en `origin.git/main`, lineales.
- Ambos clones y el bare apuntan al mismo hash.
- Alice y Bob tienen `origin/main` al día.
- `tests/validate.sh` termina con `RESULT: 7/7 checks OK`.

## 7. Criterios de aceptación

- [ ] Bare y clones existen y son del tipo correcto.
- [ ] Los 3 commits de feature están en el bare, con los subjects exactos.
- [ ] `main` lineal en el bare.
- [ ] Ninguna rama extra pusheada.
- [ ] Alice y Bob sincronizados con el bare.
- [ ] Alice y Bob tienen su `origin/main` al día (hiciste fetch al final).

## 8. Validación

```bash
bash tests/validate.sh /tmp/gh-04-collab
```

Siete checks nombrados; cada uno te dice qué espera si falla.

## 9. Preguntas de reflexión

1. ¿En qué momento ocurre exactamente el error `(non-fast-forward)` y qué información le dio Git al server para que lo rechazara?
2. Al rebasar el commit de Bob sobre `origin/main`, el **hash de ese commit cambió**. ¿Qué consecuencia tendría eso si Bob hubiera compartido su rama con otro colaborador antes del rebase?
3. ¿Por qué `git pull --rebase` y `git fetch && git rebase origin/main` producen el mismo resultado? ¿Qué prefieres y por qué?
4. Si en vez de `rebase` hubieras usado `merge origin/main`, ¿qué habría cambiado en la historia del bare? ¿Lo detectaría el validador?
5. ¿Qué habría pasado si Alice y Bob hubieran editado la **misma línea** del mismo archivo antes de pushear? Describe la secuencia de recuperación.
6. ¿Qué política configurarías globalmente (`git config --global ...`) para que un júnior nunca cree merge commits accidentales al pullear? Dame 3 settings mínimo.

## 10. Extensiones (opcional)

- **E1** — Añade un tercer colaborador "Carol" (crea `carol/`) y simula un conflicto real en `alice.md` entre Carol y Bob. Resuélvelo durante el rebase.
- **E2** — Crea una rama de feature `feature/colors` en el bob/ (`git push -u origin feature/colors`), haz 2 commits, rebasa sobre `origin/main` tras un cambio en main, y usa `git push --force-with-lease`. Explica por qué `--force-with-lease` es seguro aquí y no en `main`.
- **E3** — Experimenta con `git push --delete origin feature/colors` y `git fetch --prune` en el otro clon; verifica que `refs/remotes/origin/feature/colors` desaparece solo con prune.
- **E4** — Investiga `git ls-remote` y escribe un script que, dado el URL del bare, imprima las ramas con sus hashes sin necesidad de clonar.

## 11. Limpieza

```bash
rm -rf /tmp/gh-04-collab
```

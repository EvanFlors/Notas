# Ejemplo 01 — PR template (único y múltiple)

## Concepto que demuestra

Dos formas en que GitHub permite prellenar el cuerpo de un Pull Request:

1. **Único**: `.github/PULL_REQUEST_TEMPLATE.md` — se usa para **todos** los PRs del repo.
2. **Múltiples**: carpeta `.github/PULL_REQUEST_TEMPLATE/<nombre>.md` — se eligen vía query string al abrir el PR (`?template=<nombre>.md`).

Un repo serio tiene al menos la variante única. La múltiple ayuda cuando conviven flujos muy distintos (bugfix / feature / release / docs).

## Estructura

```
examples/01-pr-template/
├── README.md                            # este archivo
└── .github/
    ├── PULL_REQUEST_TEMPLATE.md         # plantilla por defecto
    └── PULL_REQUEST_TEMPLATE/
        ├── bugfix.md                    # plantilla específica para bugfix
        ├── feature.md                   # plantilla específica para feature
        └── release.md                   # plantilla específica para release
```

> Importante: GitHub busca **primero** `.github/PULL_REQUEST_TEMPLATE.md`. Si existe y no se pasa `?template=`, se usa esa. Si pasas `?template=feature.md`, carga la variante de la carpeta.

## Cómo probarlo (sin GitHub)

Puedes copiar la estructura `.github/` a un repo tuyo y abrir cualquier PR nuevo; GitHub prellenará el cuerpo automáticamente.

En **MODE=local** (sin GitHub) el *template* es simplemente un archivo que copias al abrir el PR a mano:

```bash
cp .github/PULL_REQUEST_TEMPLATE.md .pr/PR-$(date +%s).md
$EDITOR .pr/PR-$(date +%s).md
```

## Cómo usar los templates múltiples (en GitHub real)

Pasa el nombre del archivo como query param al link de "nuevo PR":

```
https://github.com/<org>/<repo>/compare/main...feat/x?template=feature.md&quick_pull=1
```

Equivalente con `gh`:

```bash
gh pr create --template feature.md
```

## Lectura recomendada

Lee `.github/PULL_REQUEST_TEMPLATE.md` y las 3 variantes. Observa que **todas** respetan la misma estructura general: Summary → Changes → Linked issues → Test plan → Risk / rollback. Lo que cambia es qué secciones son obligatorias y cuáles tienen placeholders específicos.

## Puntos clave

- La plantilla **no obliga** a nada; es un recordatorio. La disciplina del autor es lo que la hace útil.
- Si en 3 meses nadie llena la sección "Risk / rollback", quizá sobra; **mide**, no decores.
- El PR template cuenta como código: va en PR, se revisa, se versiona.

#!/usr/bin/env python3
"""compute_dashboard.py - Dashboard de progreso para ci-cd-engineering-academy.

Escanea `courses/*/*/activities/*/activity.yaml` y
`projects/capstone/stages/*/activities/*/activity.yaml`, agrega metricas
por curso / nivel / dimension y emite un reporte Markdown en stdout.

Metricas DORA-style sobre el trabajo del propio estudiante se derivan
del historial `git log` de cada `activity.yaml` (cuando el repo es un
clon git); si git no esta disponible la seccion se omite con un aviso.

Solo depende de la biblioteca estandar (sin PyYAML, sin pandas).

Uso:
    python3 compute_dashboard.py [--repo PATH] [--out FILE]

Si --out se omite el reporte va a stdout.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

STATUS_VALUES = ("not-started", "in-progress", "blocked", "completed")

# Mapeo heuristico type -> dimension (ver evaluation/00-master-rubric.md).
TYPE_TO_DIMENSION = {
    "guided-lab": "operativa",
    "independent": "operativa",
    "debug": "operativa",
    "scenario": "operativa",
    "architecture": "arquitectonica",
    "mini-project": "arquitectonica",
    "demo": "conceptual",
}

# Nombres de cursos (dir names bajo courses/) usados para orden estable.
COURSE_ORDER = [
    "git-and-github",
    "github-actions",
    "gitlab-cicd",
    "jenkins",
    "docker",
    "kubernetes",
    "helm",
    "argocd-gitops",
    "terraform",
    "ansible",
    "aws",
    "gcp",
    "azure",
    "prometheus-grafana",
    "opentelemetry",
    "devsecops",
    "platform-engineering",
]


# ---------------------------------------------------------------------------
# Mini-parser YAML (solo lo que necesitamos de activity.yaml: pares
# clave: valor escalares y listas simples con guion). Ignora comentarios.
# ---------------------------------------------------------------------------

def parse_activity_yaml(path: Path) -> Dict[str, object]:
    data: Dict[str, object] = {}
    current_list_key: Optional[str] = None
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        return data
    for line in raw.splitlines():
        stripped = line.rstrip()
        if not stripped or stripped.lstrip().startswith("#"):
            continue
        # Elemento de lista
        if stripped.lstrip().startswith("- ") and current_list_key is not None:
            value = stripped.lstrip()[2:].strip().strip('"').strip("'")
            data.setdefault(current_list_key, []).append(value)  # type: ignore[union-attr]
            continue
        # Linea con `clave: valor` a nivel raiz (sin indent).
        if ":" in stripped and not stripped.startswith(" "):
            key, _, value = stripped.partition(":")
            key = key.strip()
            value = value.strip()
            if value == "":
                current_list_key = key
                continue
            current_list_key = None
            # Quitar comillas y comentarios inline.
            if "#" in value and not value.startswith('"'):
                value = value.split("#", 1)[0].strip()
            value = value.strip('"').strip("'")
            data[key] = value
        else:
            # Linea indentada que no es un item de lista: la ignoramos
            # (nested mapping como `paths:` queda vacio -> OK para el agregado).
            current_list_key = None
    return data


# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------

@dataclass
class Activity:
    path: Path
    activity_id: str
    technology: str
    module: str
    level: str
    type_: str
    status: str
    estimated_minutes: int
    scope: str  # "course" o "capstone"

    @property
    def dimension(self) -> str:
        return TYPE_TO_DIMENSION.get(self.type_, "operativa")


@dataclass
class Bucket:
    total: int = 0
    completed: int = 0
    in_progress: int = 0
    blocked: int = 0
    not_started: int = 0
    minutes_total: int = 0
    minutes_completed: int = 0

    def add(self, a: Activity) -> None:
        self.total += 1
        self.minutes_total += a.estimated_minutes
        if a.status == "completed":
            self.completed += 1
            self.minutes_completed += a.estimated_minutes
        elif a.status == "in-progress":
            self.in_progress += 1
        elif a.status == "blocked":
            self.blocked += 1
        else:
            self.not_started += 1

    @property
    def pct(self) -> float:
        return (self.completed / self.total * 100.0) if self.total else 0.0


# ---------------------------------------------------------------------------
# Carga
# ---------------------------------------------------------------------------

def discover_activities(repo: Path) -> List[Activity]:
    results: List[Activity] = []
    patterns: List[Tuple[Path, str]] = [
        (repo / "courses", "course"),
        (repo / "projects" / "capstone" / "stages", "capstone"),
    ]
    for root, scope in patterns:
        if not root.exists():
            continue
        for yml in root.rglob("activity.yaml"):
            data = parse_activity_yaml(yml)
            try:
                minutes = int(str(data.get("estimated_minutes", "0")).strip() or "0")
            except ValueError:
                minutes = 0
            activity = Activity(
                path=yml,
                activity_id=str(data.get("id", yml.parent.name)),
                technology=str(data.get("technology", "unknown")),
                module=str(data.get("module", yml.parent.parent.parent.name)),
                level=str(data.get("level", "unknown")),
                type_=str(data.get("type", "unknown")),
                status=str(data.get("status", "not-started")),
                estimated_minutes=minutes,
                scope=scope,
            )
            if activity.status not in STATUS_VALUES:
                activity.status = "not-started"
            results.append(activity)
    return results


# ---------------------------------------------------------------------------
# Git / DORA
# ---------------------------------------------------------------------------

def git_available(repo: Path) -> bool:
    try:
        r = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            check=False,
        )
        return r.returncode == 0 and r.stdout.strip() == "true"
    except FileNotFoundError:
        return False


def file_commit_timestamps(repo: Path, path: Path) -> List[datetime]:
    try:
        r = subprocess.run(
            ["git", "-C", str(repo), "log", "--format=%aI", "--follow", "--", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return []
    out: List[datetime] = []
    for line in r.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(datetime.fromisoformat(line))
        except ValueError:
            continue
    return out


def dora_stats(repo: Path, activities: Iterable[Activity]) -> Dict[str, object]:
    completed = [a for a in activities if a.status == "completed"]
    stats: Dict[str, object] = {
        "completed_count": len(completed),
        "lead_times_hours": [],
        "throughput_per_week": {},
        "bottlenecks": [],
    }
    if not completed:
        return stats

    lead_times: List[float] = []
    completion_dates: List[datetime] = []
    per_course_times: Dict[str, List[float]] = defaultdict(list)

    for a in completed:
        ts = file_commit_timestamps(repo, a.path)
        if len(ts) < 2:
            continue
        first = min(ts)
        last = max(ts)
        hours = (last - first).total_seconds() / 3600.0
        lead_times.append(hours)
        completion_dates.append(last.astimezone(timezone.utc))
        per_course_times[a.technology].append(hours)

    stats["lead_times_hours"] = lead_times

    throughput: Dict[str, int] = defaultdict(int)
    for d in completion_dates:
        # ISO week key YYYY-Www
        iso = d.isocalendar()
        throughput[f"{iso.year}-W{iso.week:02d}"] += 1
    stats["throughput_per_week"] = dict(sorted(throughput.items()))

    bottlenecks = sorted(
        ((course, sum(v) / len(v)) for course, v in per_course_times.items() if v),
        key=lambda kv: kv[1],
        reverse=True,
    )[:5]
    stats["bottlenecks"] = bottlenecks

    return stats


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

def pct_bar(pct: float, width: int = 20) -> str:
    filled = int(round(pct / 100 * width))
    return "`" + "#" * filled + "-" * (width - filled) + f"` {pct:5.1f}%"


def render_bucket_table(title: str, buckets: Dict[str, Bucket], key_label: str) -> str:
    lines = [f"### {title}", "",
             f"| {key_label} | Total | Completadas | En curso | Bloqueadas | Pendientes | % |",
             "|---|---:|---:|---:|---:|---:|---|"]
    for key, b in buckets.items():
        lines.append(
            f"| {key} | {b.total} | {b.completed} | {b.in_progress} | "
            f"{b.blocked} | {b.not_started} | {pct_bar(b.pct)} |"
        )
    lines.append("")
    return "\n".join(lines)


def render_report(repo: Path, activities: List[Activity], include_dora: bool) -> str:
    per_course: Dict[str, Bucket] = {}
    per_level: Dict[str, Bucket] = defaultdict(Bucket)
    per_dim: Dict[str, Bucket] = defaultdict(Bucket)
    per_capstone_stage: Dict[str, Bucket] = defaultdict(Bucket)
    global_bucket = Bucket()

    # orden de cursos estable
    for c in COURSE_ORDER:
        per_course[c] = Bucket()

    for a in activities:
        global_bucket.add(a)
        per_level[a.level].add(a)
        per_dim[a.dimension].add(a)
        if a.scope == "capstone":
            per_capstone_stage[a.module].add(a)
        else:
            per_course.setdefault(a.technology, Bucket()).add(a)

    # Quitar cursos sin actividades (si algun dir aun no tiene).
    per_course_clean = {k: v for k, v in per_course.items() if v.total > 0}

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    header = [
        "# Dashboard de progreso — ci-cd-engineering-academy",
        "",
        f"_Generado: {now}_  ",
        f"_Repo: `{repo}`_",
        "",
        "## Resumen global",
        "",
        f"- Actividades totales: **{global_bucket.total}**",
        f"- Completadas: **{global_bucket.completed}** "
        f"({global_bucket.pct:.1f}%)",
        f"- En curso: {global_bucket.in_progress}",
        f"- Bloqueadas: {global_bucket.blocked}",
        f"- Pendientes: {global_bucket.not_started}",
        f"- Minutos estimados totales: {global_bucket.minutes_total:,}",
        f"- Minutos estimados completados: {global_bucket.minutes_completed:,}",
        "",
    ]

    body = [
        render_bucket_table("Por curso", per_course_clean, "Curso"),
        render_bucket_table(
            "Por nivel",
            {k: per_level[k] for k in sorted(per_level)},
            "Nivel",
        ),
        render_bucket_table(
            "Por dimension",
            {k: per_dim[k] for k in sorted(per_dim)},
            "Dimension",
        ),
    ]
    if per_capstone_stage:
        body.append(
            render_bucket_table(
                "Capstone — por etapa",
                {k: per_capstone_stage[k] for k in sorted(per_capstone_stage)},
                "Etapa",
            )
        )

    dora_section = ["## DORA-style sobre el trabajo del estudiante", ""]
    if not include_dora:
        dora_section.append(
            "_Git no esta disponible en este entorno; seccion omitida._"
        )
    else:
        stats = dora_stats(repo, activities)
        completed = stats["completed_count"]
        if completed == 0:
            dora_section += [
                "Aun no hay actividades con `status: completed`.",
                "",
                "**Formulas que se calcularan cuando haya datos:**",
                "- *Lead time*: diferencia entre el primer y el ultimo commit",
                "  que toca cada `activity.yaml` completado.",
                "- *Throughput*: numero de actividades completadas por semana ISO.",
                "- *Bottlenecks*: cursos con mayor lead time promedio.",
            ]
        else:
            lt = stats["lead_times_hours"]  # type: ignore[assignment]
            lt_list: List[float] = lt  # type: ignore[assignment]
            avg = sum(lt_list) / len(lt_list) if lt_list else 0.0
            lt_sorted = sorted(lt_list)
            median = lt_sorted[len(lt_sorted) // 2] if lt_sorted else 0.0
            dora_section += [
                f"- Actividades completadas: **{completed}**",
                f"- Lead time medio: **{avg:.1f} h**  |  mediana: **{median:.1f} h**",
                "",
                "### Throughput por semana",
                "",
                "| Semana ISO | Completadas |",
                "|---|---:|",
            ]
            for wk, n in stats["throughput_per_week"].items():  # type: ignore[union-attr]
                dora_section.append(f"| {wk} | {n} |")
            dora_section += ["", "### Bottlenecks (top 5 por lead time medio)", "",
                             "| Curso | Lead time medio (h) |", "|---|---:|"]
            for course, hours in stats["bottlenecks"]:  # type: ignore[union-attr]
                dora_section.append(f"| {course} | {hours:.1f} |")
    dora_section.append("")

    footer = [
        "---",
        "",
        "## Notas",
        "",
        "- La *dimension* se infiere de `type` segun `TYPE_TO_DIMENSION`",
        "  en `compute_dashboard.py`; ajustar ahi si cambia el criterio.",
        "- Estados reconocidos: `not-started`, `in-progress`, `blocked`,",
        "  `completed`. Cualquier otro valor se normaliza a `not-started`.",
        "- El parser YAML es minimalista (solo escalares y listas raiz).",
        "  Si se introducen nuevos campos anidados obligatorios, actualizar.",
    ]

    return "\n".join(header + body + dora_section + footer).rstrip() + "\n"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        default=str(Path(__file__).resolve().parents[2]),
        help="Raiz del repo (por defecto: dos niveles por encima del script).",
    )
    parser.add_argument("--out", default=None, help="Ruta de salida (default: stdout).")
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    activities = discover_activities(repo)
    include_dora = git_available(repo)
    report = render_report(repo, activities, include_dora)

    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
        print(f"wrote {args.out} ({len(activities)} activities)", file=sys.stderr)
    else:
        sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

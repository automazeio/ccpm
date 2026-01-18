from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping


class ConfigError(RuntimeError):
    pass


DEFAULT_CONFIG: dict[str, Any] = {
    "parallelism": {"max_workers": 12},
    "sync": {
        "mode": "event_and_periodic",
        "periodic_minutes": 30,
        "post_level": "epic_summary",
        "always_post_on_error": True,
    },
    "git": {
        "main_branch": "main",
        "integration_branch_prefix": "integration/",
        "issue_branch_prefix": "issue/",
        "merge_strategy": "merge_commit",
    },
    "testing": {
        "lanes": {
            "fast": {"required": True, "skill": "testing:fast"},
            "gate": {"required": True, "skill": "testing:gate"},
            "full": {"required": True, "skill": "testing:full"},
        }
    },
    "retries": {
        "transient_max": 2,
        "step_max_if_previously_succeeded": 3,
    },
    "safety": {
        "kill_switch_file": ".claude/orchestrator/STOP",
        "require_clean_worktree_for_merge": True,
    },
}


@dataclass(frozen=True)
class OrchestratorConfig:
    data: dict[str, Any]

    def get(self, key: str, default: Any | None = None) -> Any:
        return self.data.get(key, default)


def _deep_merge(base: Mapping[str, Any], override: Mapping[str, Any]) -> dict[str, Any]:
    merged: dict[str, Any] = dict(base)
    for key, value in override.items():
        if isinstance(value, Mapping) and isinstance(merged.get(key), Mapping):
            merged[key] = _deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def _load_yaml(path: Path) -> dict[str, Any]:
    try:
        import yaml  # type: ignore
    except ModuleNotFoundError as exc:
        raise ConfigError(
            "PyYAML is required to load orchestrator config.yaml."
        ) from exc

    with path.open("r", encoding="utf-8") as handle:
        raw = yaml.safe_load(handle) or {}
    if not isinstance(raw, Mapping):
        raise ConfigError("Config file must parse to a mapping.")
    return dict(raw)


def config_path(base_dir: Path | str | None = None) -> Path:
    base = Path(base_dir) if base_dir is not None else Path.cwd()
    return base / ".claude" / "orchestrator" / "config.yaml"


def load_config(base_dir: Path | str | None = None) -> OrchestratorConfig:
    path = config_path(base_dir)
    if not path.exists():
        return OrchestratorConfig(dict(DEFAULT_CONFIG))
    overrides = _load_yaml(path)
    merged = _deep_merge(DEFAULT_CONFIG, overrides)
    return OrchestratorConfig(merged)

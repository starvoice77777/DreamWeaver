"""In-process HTTP metrics (Prometheus text exposition, no extra dependency)."""

from __future__ import annotations

import re
import threading
from collections import defaultdict

_UUID_RE = re.compile(
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)

_lock = threading.Lock()
_request_counts: dict[tuple[str, str, str], int] = defaultdict(int)
_duration_sum_ms: dict[tuple[str, str], float] = defaultdict(float)
_duration_count: dict[tuple[str, str], int] = defaultdict(int)


def normalize_path(path: str) -> str:
    """Collapse UUIDs so label cardinality stays bounded."""
    return _UUID_RE.sub("{id}", path)


def observe_request(*, method: str, path: str, status_code: int, duration_ms: float) -> None:
    route = normalize_path(path)
    status = str(status_code)
    key_count = (method, route, status)
    key_dur = (method, route)
    with _lock:
        _request_counts[key_count] += 1
        _duration_sum_ms[key_dur] += duration_ms
        _duration_count[key_dur] += 1


def reset_metrics() -> None:
    """Test helper."""
    with _lock:
        _request_counts.clear()
        _duration_sum_ms.clear()
        _duration_count.clear()


def render_prometheus() -> str:
    lines: list[str] = [
        "# HELP http_requests_total Total HTTP requests",
        "# TYPE http_requests_total counter",
    ]
    with _lock:
        counts = list(_request_counts.items())
        dur_sum = dict(_duration_sum_ms)
        dur_count = dict(_duration_count)

    for (method, path, status), value in sorted(counts):
        lines.append(
            f'http_requests_total{{method="{method}",path="{path}",status="{status}"}} {value}'
        )

    lines.append("# HELP http_request_duration_milliseconds_sum Request duration sum (ms)")
    lines.append("# TYPE http_request_duration_milliseconds_sum counter")
    for (method, path), total in sorted(dur_sum.items()):
        lines.append(
            f'http_request_duration_milliseconds_sum{{method="{method}",path="{path}"}} {total:.3f}'
        )

    lines.append("# HELP http_request_duration_milliseconds_count Request duration sample count")
    lines.append("# TYPE http_request_duration_milliseconds_count counter")
    for (method, path), count in sorted(dur_count.items()):
        lines.append(
            f'http_request_duration_milliseconds_count{{method="{method}",path="{path}"}} {count}'
        )

    lines.append("")
    return "\n".join(lines)

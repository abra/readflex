"""Writes fsrs6_reference.json: FSRS-6 memory states from py-fsrs.

py-fsrs (open-spaced-repetition/py-fsrs) is the algorithm's reference
implementation in Python, apart from the Rust crate the app schedules
with. Every case replays a review history through its Scheduler and
records, after each review, the stability and the difficulty, the
interval py-fsrs would give for them at the case's retention, and, after
the last, the retrievability some whole days later.

    git clone https://github.com/open-spaced-repetition/py-fsrs
    python3 -I fsrs6_reference.py path/to/py-fsrs > fsrs6_reference.json

Histories keep every review in one place of the day (13:53 in UTC+5,
minutes added stay under 14 hours in all), so py-fsrs's 24-hour days and
the app's study days, which start at 04:00, agree; stability stays under
36500 days, where the crate caps it and py-fsrs does not.
"""

import json
import random
import subprocess
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, sys.argv[1])
from fsrs import Card, Rating, Scheduler  # noqa: E402
from fsrs.scheduler import (  # noqa: E402
    DEFAULT_PARAMETERS,
    LOWER_BOUNDS_PARAMETERS,
    UPPER_BOUNDS_PARAMETERS,
)

MINUTE = 60_000
DAY = 24 * 60 * MINUTE
T0 = datetime.fromtimestamp(1_760_000_000, timezone.utc)
RETENTIONS = [0.9, 0.85, 0.7, 0.8, 0.95, 0.97]
LATER = [1, 3, 10, 30, 100, 365]

# The histories of fsrs6.rs, as (rating, ms since the review before).
HISTORIES = [
    [(4, 0), (3, 8 * DAY), (2, 50 * DAY), (4, 3 * DAY), (1, 40 * DAY), (3, 10 * MINUTE), (3, 5 * DAY)],
    [(3, 0), (1, 10 * MINUTE), (2, 5 * MINUTE), (3, 10 * MINUTE), (4, 2 * DAY), (1, 9 * DAY)],
    [(1, 0), (1, MINUTE), (3, 5 * MINUTE), (1, DAY), (3, 5 * MINUTE), (2, 6 * DAY)],
    [(2, 0), (4, 5 * MINUTE), (3, 20 * DAY), (3, 400 * DAY), (2, 30 * DAY)],
]

# The second value fsrs6.rs gives each parameter.
OTHER = [0.5, 2.0, 4.0, 12.0, 7.5, 0.4, 1.5, 0.2, 1.2, 0.4, 1.5, 2.5, 0.2, 0.5, 0.8, 0.3, 3.0, 1.0, 0.5, 0.3, 0.5]


def random_history(rng):
    history = [(rng.randint(1, 4), 0)]
    for _ in range(14):
        after = rng.randint(1, 50) * MINUTE if rng.random() < 0.3 else rng.randint(1, 400) * DAY
        history.append((rng.randint(1, 4), after))
    return history


def random_parameters(rng):
    # The same-day terms kept modest, as in fsrs6.rs.
    return [
        rng.uniform(low, min(high, 1.0) if i in (17, 18) else high)
        for i, (low, high) in enumerate(zip(LOWER_BOUNDS_PARAMETERS, UPPER_BOUNDS_PARAMETERS))
    ]


def case(label, parameters, retention, history):
    scheduler = Scheduler(
        parameters=parameters, desired_retention=retention, maximum_interval=36500, enable_fuzzing=False
    )
    card = Card(card_id=1, due=T0)
    at = T0
    memory, intervals = [], []
    for rating, after in history:
        at += timedelta(milliseconds=after)
        card, _ = scheduler.review_card(card, Rating(rating), review_datetime=at)
        memory.append([card.stability, card.difficulty])
        intervals.append(scheduler._next_interval(stability=card.stability))
    if max(s for s, _ in memory) >= 36500:
        return None
    later = [[days, scheduler.get_card_retrievability(card, card.last_review + timedelta(days=days))] for days in LATER]
    return {
        "label": label,
        "parameters": list(parameters),
        "retention": retention,
        "reviews": history,
        "memory": memory,
        "intervals": intervals,
        "retrievability": later,
    }


def main():
    rng = random.Random(6)
    retentions = iter(RETENTIONS * 100)
    cases = []
    for h, history in enumerate(HISTORIES):
        cases.append(case(f"defaults, history {h}", DEFAULT_PARAMETERS, next(retentions), history))
    while len(cases) < len(HISTORIES) + 6:
        n = len(cases) - len(HISTORIES)
        made = case(f"defaults, random history {n}", DEFAULT_PARAMETERS, next(retentions), random_history(rng))
        cases += [made] if made else []
    for i in range(21):
        parameters = list(DEFAULT_PARAMETERS)
        parameters[i] = OTHER[i]
        for h, history in enumerate(HISTORIES):
            cases.append(case(f"w{i} = {OTHER[i]}, history {h}", parameters, next(retentions), history))
    for s in range(8):
        parameters = random_parameters(rng)
        made = 0
        while made < 3:
            one = case(f"random set {s}, history {made}", parameters, next(retentions), random_history(rng))
            if one:
                cases.append(one)
                made += 1
    commit = subprocess.run(
        ["git", "-C", sys.argv[1], "rev-parse", "HEAD"], capture_output=True, text=True, check=True
    ).stdout.strip()
    version = next(
        line.split('"')[1] for line in open(f"{sys.argv[1]}/pyproject.toml") if line.startswith("version")
    )
    # One case a line, twelve significant digits: well past f32's.
    def short(value):
        if isinstance(value, float):
            return float(f"{value:.12g}")
        if isinstance(value, (list, tuple)):
            return [short(v) for v in value]
        if isinstance(value, dict):
            return {k: short(v) for k, v in value.items()}
        return value

    source = f"py-fsrs {version} (open-spaced-repetition/py-fsrs@{commit[:12]})"
    lines = ",\n".join(json.dumps(short(c), separators=(",", ":")) for c in cases)
    sys.stdout.write(f'{{"source":{json.dumps(source)},"cases":[\n{lines}\n]}}\n')


main()

#!/usr/bin/env sh
set -eu

# yabai's window --ratio changes the immediate parent of a leaf. Find a leaf
# touching the root split, then resize that edge so only the root ratio moves.
ratio="${1:-}"
[ -n "$ratio" ] || { printf 'usage: %s 0.2..0.8\n' "$0" >&2; exit 2; }
python3 - "$ratio" <<'PY'
import functools
import json
import subprocess
import sys


def query(*args):
    return json.loads(subprocess.check_output(["yabai", "-m", "query", *args]))


try:
    wanted = float(sys.argv[1])
    if not 0.1 <= wanted <= 0.9:
        raise ValueError("ratio must be between 0.1 and 0.9")

    space = query("--spaces", "--space")
    if space["type"] != "bsp":
        raise ValueError("the focused space is not BSP")

    # Windows in one stack share a leaf and frame. Keep one id for that leaf.
    leaves = {}
    for window in query("--windows", "--space"):
        if window["is-floating"] or window["is-minimized"] or window["is-hidden"]:
            continue
        frame = window["frame"]
        key = (frame["x"], frame["y"], frame["w"], frame["h"])
        leaves.setdefault(key, window)

    windows = list(leaves.values())
    if len(windows) < 2:
        raise ValueError("the focused space needs at least two BSP leaves")

    by_id = {window["id"]: window for window in windows}

    def bounds(ids):
        frames = [by_id[wid]["frame"] for wid in ids]
        return (
            min(frame["x"] for frame in frames),
            min(frame["y"] for frame in frames),
            max(frame["x"] + frame["w"] for frame in frames),
            max(frame["y"] + frame["h"] for frame in frames),
        )

    def candidates(ids):
        parent = bounds(ids)
        for axis in ("vertical", "horizontal"):
            coordinate = "x" if axis == "vertical" else "y"
            ordered = sorted(ids, key=lambda wid: by_id[wid]["frame"][coordinate])
            for split in range(1, len(ordered)):
                first = tuple(sorted(ordered[:split]))
                second = tuple(sorted(ordered[split:]))
                first_box = bounds(first)
                second_box = bounds(second)
                if axis == "vertical":
                    separated = first_box[2] < second_box[0]
                    spans = (
                        abs(first_box[1] - parent[1]) <= 2
                        and abs(first_box[3] - parent[3]) <= 2
                        and abs(second_box[1] - parent[1]) <= 2
                        and abs(second_box[3] - parent[3]) <= 2
                    )
                else:
                    separated = first_box[3] < second_box[1]
                    spans = (
                        abs(first_box[0] - parent[0]) <= 2
                        and abs(first_box[2] - parent[2]) <= 2
                        and abs(second_box[0] - parent[0]) <= 2
                        and abs(second_box[2] - parent[2]) <= 2
                    )
                if not separated or not spans:
                    continue
                if len(first) == 1:
                    leaf = by_id[first[0]]
                    if leaf["split-type"] != axis or leaf["split-child"] != "first_child":
                        continue
                if len(second) == 1:
                    leaf = by_id[second[0]]
                    if leaf["split-type"] != axis or leaf["split-child"] != "second_child":
                        continue
                yield axis, first, second, first_box, second_box

    @functools.lru_cache(None)
    def valid(ids):
        if len(ids) == 1:
            return True
        return any(valid(first) and valid(second) for _, first, second, _, _ in candidates(ids))

    roots = [
        item for item in candidates(tuple(sorted(by_id)))
        if valid(item[1]) and valid(item[2])
    ]
    if len(roots) != 1:
        raise ValueError("could not identify one top-level BSP split")

    axis, first, _, first_box, second_box = roots[0]
    parent_box = bounds(tuple(by_id))
    if axis == "vertical":
        first_size = first_box[2] - first_box[0]
        second_size = second_box[2] - second_box[0]
        total_size = parent_box[2] - parent_box[0]
        target = max(first, key=lambda wid: by_id[wid]["frame"]["x"] + by_id[wid]["frame"]["w"])
        handle = "right"
        delta = (wanted - first_size / (first_size + second_size)) * total_size
        resize = f"{handle}:{delta:.2f}:0"
    else:
        first_size = first_box[3] - first_box[1]
        second_size = second_box[3] - second_box[1]
        total_size = parent_box[3] - parent_box[1]
        target = max(first, key=lambda wid: by_id[wid]["frame"]["y"] + by_id[wid]["frame"]["h"])
        handle = "bottom"
        delta = (wanted - first_size / (first_size + second_size)) * total_size
        resize = f"{handle}:0:{delta:.2f}"

    if abs(delta) >= 1:
        subprocess.run(["yabai", "-m", "window", str(target), "--resize", resize], check=True)
except (ValueError, KeyError, subprocess.CalledProcessError) as error:
    print(f"root-split-ratio: {error}", file=sys.stderr)
    sys.exit(1)
PY

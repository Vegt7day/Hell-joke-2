#!/usr/bin/env python3
"""
World3 Boss Y-axis PID response simulator.

Purpose:
- Reproduce the current movement model in `boss_horse_main.gd`:
  x_cmd = -1, y_cmd = PID(error_y), then normalize([x_cmd, y_cmd]) * horse_speed.
- Use current default speeds from project scripts by parsing:
  - entities/player/real player/student.gd -> move_speed
  - system/levels/world3/bosses/boss_horse_main.gd -> move_left_speed
- Plot Y-axis response for PID tuning.

Usage examples:
  python tools/world3_pid_y_response_sim.py
  python tools/world3_pid_y_response_sim.py --kp 0.06 --ki 0.0005 --kd 0.03
  python tools/world3_pid_y_response_sim.py --scenario sine --duration 20 --dt 0.01
  python tools/world3_pid_y_response_sim.py --no-plot
"""

from __future__ import annotations

import argparse
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Tuple


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PLAYER_GD = PROJECT_ROOT / "entities" / "player" / "real player" / "student.gd"
BOSS_GD = PROJECT_ROOT / "system" / "levels" / "world3" / "bosses" / "boss_horse_main.gd"


@dataclass
class SpeedConfig:
    player_speed: float
    horse_speed: float


@dataclass
class PidConfig:
    kp: float
    ki: float
    kd: float
    integral_limit: float
    output_limit: float


def _read_export_float(path: Path, var_name: str, fallback: float) -> float:
    if not path.exists():
        return fallback
    text = path.read_text(encoding="utf-8", errors="ignore")
    pattern = rf"@export\s+var\s+{re.escape(var_name)}\s*:\s*float\s*=\s*([-+]?\d*\.?\d+)"
    m = re.search(pattern, text)
    if not m:
        return fallback
    try:
        return float(m.group(1))
    except ValueError:
        return fallback


def load_speed_config() -> SpeedConfig:
    player_speed = _read_export_float(PLAYER_GD, "move_speed", 200.0)
    horse_speed = _read_export_float(BOSS_GD, "move_left_speed", 90.0)
    return SpeedConfig(player_speed=player_speed, horse_speed=horse_speed)


def player_motion(
    t: float,
    x0: float,
    y0: float,
    player_speed: float,
    scenario: str,
) -> Tuple[float, float]:
    # Player motion only drives target Y; X is included for completeness.
    if scenario == "step":
        # t < 2s at y0, then jump upward by +220 units.
        y = y0 if t < 2.0 else y0 + 220.0
        x = x0
    elif scenario == "sine":
        amp = 160.0
        freq = 0.25  # Hz
        y = y0 + amp * math.sin(2.0 * math.pi * freq * t)
        x = x0
    elif scenario == "zigzag":
        # Piecewise linear vertical movement bounded by player_speed.
        period = 4.0
        phase = (t % period) / period
        if phase < 0.25:
            vy = player_speed
        elif phase < 0.5:
            vy = -player_speed
        elif phase < 0.75:
            vy = -player_speed
        else:
            vy = player_speed
        y = y0 + 120.0 * math.sin(2.0 * math.pi * t / period) + 0.25 * vy
        x = x0
    else:
        y = y0
        x = x0
    return x, y


def simulate(
    duration: float,
    dt: float,
    speed_cfg: SpeedConfig,
    pid_cfg: PidConfig,
    scenario: str,
) -> dict:
    steps = max(1, int(duration / dt))

    player_x, player_y = 300.0, 0.0
    boss_x, boss_y = 520.0, -80.0

    integ = 0.0
    prev_err = 0.0

    ts, py, by, ey, vy, vx = [], [], [], [], [], []

    for i in range(steps + 1):
        t = i * dt
        player_x, player_y = player_motion(t, player_x, 0.0, speed_cfg.player_speed, scenario)

        err = player_y - boss_y
        integ = max(-pid_cfg.integral_limit, min(pid_cfg.integral_limit, integ + err * dt))
        derr = (err - prev_err) / dt if dt > 1e-6 else 0.0
        prev_err = err

        y_cmd = pid_cfg.kp * err + pid_cfg.ki * integ + pid_cfg.kd * derr
        y_cmd = max(-pid_cfg.output_limit, min(pid_cfg.output_limit, y_cmd))

        # Match game logic: Vector2(-1, y_cmd).normalized() * move_left_speed
        cmd_x = -1.0
        cmd_y = y_cmd
        length = math.hypot(cmd_x, cmd_y)
        if length <= 1e-8:
            vel_x = -speed_cfg.horse_speed
            vel_y = 0.0
        else:
            vel_x = (cmd_x / length) * speed_cfg.horse_speed
            vel_y = (cmd_y / length) * speed_cfg.horse_speed

        boss_x += vel_x * dt
        boss_y += vel_y * dt

        ts.append(t)
        py.append(player_y)
        by.append(boss_y)
        ey.append(err)
        vy.append(vel_y)
        vx.append(vel_x)

    return {
        "t": ts,
        "player_y": py,
        "boss_y": by,
        "error_y": ey,
        "boss_vy": vy,
        "boss_vx": vx,
        "player_speed": speed_cfg.player_speed,
        "horse_speed": speed_cfg.horse_speed,
    }


def draw(result: dict, title_suffix: str) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception as exc:  # pragma: no cover
        print("matplotlib 不可用，无法绘图。可先安装: pip install matplotlib")
        print(f"详细错误: {exc}")
        return

    t = result["t"]
    fig, axes = plt.subplots(3, 1, figsize=(11, 8), sharex=True)

    axes[0].plot(t, result["player_y"], label="Player Y", linewidth=2)
    axes[0].plot(t, result["boss_y"], label="Boss Y", linewidth=2)
    axes[0].set_ylabel("Position Y")
    axes[0].legend(loc="best")
    axes[0].grid(True, alpha=0.3)

    axes[1].plot(t, result["error_y"], color="tab:red", label="Y Error")
    axes[1].axhline(0.0, color="black", linewidth=1, alpha=0.4)
    axes[1].set_ylabel("Error")
    axes[1].legend(loc="best")
    axes[1].grid(True, alpha=0.3)

    axes[2].plot(t, result["boss_vy"], color="tab:green", label="Boss Vy")
    axes[2].plot(t, result["boss_vx"], color="tab:orange", label="Boss Vx")
    axes[2].set_ylabel("Velocity")
    axes[2].set_xlabel("Time (s)")
    axes[2].legend(loc="best")
    axes[2].grid(True, alpha=0.3)

    fig.suptitle(f"World3 Boss PID Y Response ({title_suffix})")
    fig.tight_layout()
    plt.show()


def main() -> None:
    speed_cfg = load_speed_config()

    parser = argparse.ArgumentParser(description="World3 Boss PID Y-axis response simulator")
    parser.add_argument("--duration", type=float, default=14.0, help="simulation duration (s)")
    parser.add_argument("--dt", type=float, default=0.0166667, help="step time (s)")
    parser.add_argument("--scenario", choices=["step", "sine", "zigzag"], default="step")
    parser.add_argument("--kp", type=float, default=0.04)
    parser.add_argument("--ki", type=float, default=0.0)
    parser.add_argument("--kd", type=float, default=0.02)
    parser.add_argument("--integral-limit", type=float, default=400.0)
    parser.add_argument("--output-limit", type=float, default=180.0)
    parser.add_argument("--player-speed", type=float, default=speed_cfg.player_speed)
    parser.add_argument("--horse-speed", type=float, default=speed_cfg.horse_speed)
    parser.add_argument("--no-plot", action="store_true", help="skip matplotlib window")
    args = parser.parse_args()

    pid_cfg = PidConfig(
        kp=args.kp,
        ki=args.ki,
        kd=args.kd,
        integral_limit=args.integral_limit,
        output_limit=args.output_limit,
    )
    speed_cfg = SpeedConfig(player_speed=args.player_speed, horse_speed=args.horse_speed)

    result = simulate(args.duration, args.dt, speed_cfg, pid_cfg, args.scenario)

    print("=== Simulation Config ===")
    print(f"player_speed   = {speed_cfg.player_speed}")
    print(f"horse_speed    = {speed_cfg.horse_speed}")
    print(
        "pid(kp,ki,kd)  = "
        f"({pid_cfg.kp}, {pid_cfg.ki}, {pid_cfg.kd}), "
        f"ilim={pid_cfg.integral_limit}, olim={pid_cfg.output_limit}"
    )
    print(f"scenario       = {args.scenario}, duration={args.duration}, dt={args.dt}")
    print("=========================")

    if not args.no_plot:
        title = (
            f"kp={pid_cfg.kp}, ki={pid_cfg.ki}, kd={pid_cfg.kd}, "
            f"Ps={speed_cfg.player_speed}, Hs={speed_cfg.horse_speed}, {args.scenario}"
        )
        draw(result, title)


if __name__ == "__main__":
    main()

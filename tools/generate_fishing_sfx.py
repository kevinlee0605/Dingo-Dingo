"""Generate the original Fishy Fish fishing SFX pack.

The sounds are deterministic, mono 44.1 kHz PCM WAV files so they can be
previewed locally and uploaded directly through Roblox Studio.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 44_100
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "sfx"


def envelope(t: float, duration: float, attack: float = 0.01, release: float = 0.2) -> float:
    attack_gain = min(1.0, t / max(attack, 1e-6))
    release_gain = min(1.0, max(0.0, duration - t) / max(release, 1e-6))
    return attack_gain * release_gain


def tone(frequency: float, t: float, phase: float = 0.0) -> float:
    return math.sin((2.0 * math.pi * frequency * t) + phase)


def soft_clip(value: float) -> float:
    return math.tanh(value * 1.25) / math.tanh(1.25)


def write_wav(name: str, samples: list[float]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    peak = max((abs(sample) for sample in samples), default=1.0)
    gain = 0.92 / max(peak, 0.92)
    pcm = bytearray()
    for sample in samples:
        value = int(max(-1.0, min(1.0, soft_clip(sample * gain))) * 32_767)
        pcm.extend(struct.pack("<h", value))

    with wave.open(str(OUTPUT_DIR / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)


def render(duration: float, sample_fn) -> list[float]:
    return [sample_fn(index / SAMPLE_RATE) for index in range(round(duration * SAMPLE_RATE))]


def make_cast() -> list[float]:
    duration = 0.48
    rng = random.Random(7)
    smoothed_noise = 0.0

    def sample(t: float) -> float:
        nonlocal smoothed_noise
        progress = t / duration
        raw_noise = rng.uniform(-1.0, 1.0)
        smoothed_noise += (raw_noise - smoothed_noise) * (0.08 + 0.34 * progress)
        whoosh = (raw_noise - smoothed_noise) * math.sin(math.pi * progress) ** 1.6
        line_whip = tone(1_350 - (820 * progress), t) * math.exp(-24 * abs(t - 0.27))
        rod_snap = tone(190, t) * math.exp(-18 * t)
        return (0.80 * whoosh + 0.24 * line_whip + 0.12 * rod_snap) * envelope(t, duration, 0.018, 0.12)

    return render(duration, sample)


def make_plop() -> list[float]:
    duration = 0.62
    rng = random.Random(11)
    low_noise = 0.0

    def sample(t: float) -> float:
        nonlocal low_noise
        raw_noise = rng.uniform(-1.0, 1.0)
        low_noise += (raw_noise - low_noise) * 0.055
        splash = (raw_noise - low_noise) * math.exp(-15 * t)
        impact = tone(108 - 35 * min(1, t / 0.22), t) * math.exp(-10 * t)
        bubble_one = tone(280 + 620 * t, t) * math.exp(-28 * abs(t - 0.18))
        bubble_two = tone(360 + 780 * t, t) * math.exp(-34 * abs(t - 0.31))
        return 0.54 * splash + 0.65 * impact + 0.17 * bubble_one + 0.12 * bubble_two

    return render(duration, sample)


def make_bite_alert() -> list[float]:
    duration = 0.72
    rng = random.Random(19)

    def bell(t: float, start: float, frequency: float, length: float) -> float:
        local = t - start
        if local < 0 or local > length:
            return 0.0
        decay = math.exp(-5.2 * local)
        return decay * (
            tone(frequency, local)
            + 0.34 * tone(frequency * 2.01, local)
            + 0.16 * tone(frequency * 3.02, local)
        )

    def sample(t: float) -> float:
        splash = rng.uniform(-1.0, 1.0) * math.exp(-32 * t) * 0.20
        alert = 0.44 * bell(t, 0.03, 880, 0.38) + 0.52 * bell(t, 0.20, 1_174.66, 0.48)
        return splash + alert

    return render(duration, sample)


def make_reel_loop() -> list[float]:
    duration = 0.80
    rng = random.Random(23)
    click_times = [index * 0.10 for index in range(8)]

    def wrapped_distance(t: float, center: float) -> float:
        direct = abs(t - center)
        return min(direct, duration - direct)

    def sample(t: float) -> float:
        whirr = 0.055 * tone(76, t) + 0.035 * tone(152, t)
        texture = rng.uniform(-1.0, 1.0) * 0.018
        clicks = 0.0
        for index, click_time in enumerate(click_times):
            distance = wrapped_distance(t, click_time)
            click_envelope = math.exp(-155 * distance)
            click_frequency = 1_650 + (index % 2) * 240
            clicks += click_envelope * (0.42 * tone(click_frequency, distance) + 0.20 * rng.uniform(-1.0, 1.0))
        return whirr + texture + clicks

    return render(duration, sample)


def make_reveal(notes: list[float], duration: float, impact: float, shimmer: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    spacing = min(0.19, (duration * 0.62) / max(1, len(notes)))

    def pluck(t: float, start: float, frequency: float) -> float:
        local = t - start
        if local < 0:
            return 0.0
        decay = math.exp(-5.8 * local)
        return decay * (
            0.68 * tone(frequency, local)
            + 0.25 * tone(frequency * 2.0, local)
            + 0.11 * tone(frequency * 3.01, local)
        )

    def sample(t: float) -> float:
        result = impact * tone(82, t) * math.exp(-12 * t)
        for index, note in enumerate(notes):
            result += pluck(t, 0.055 + spacing * index, note)
        sparkle_gate = max(0.0, math.sin(2 * math.pi * 17 * t)) ** 8
        sparkle = rng.uniform(-1.0, 1.0) * sparkle_gate * math.exp(-1.8 * t)
        rise = tone(520 + (1_150 * (t / duration)), t) * math.sin(math.pi * t / duration) ** 2
        return result + shimmer * (0.35 * sparkle + 0.16 * rise)

    return render(duration, sample)


def main() -> None:
    sounds = {
        "fish_cast.wav": make_cast(),
        "bobber_plop.wav": make_plop(),
        "bite_alert.wav": make_bite_alert(),
        "reel_loop.wav": make_reel_loop(),
        "reveal_common.wav": make_reveal([523.25, 659.25], 0.62, 0.05, 0.05, 31),
        "reveal_uncommon.wav": make_reveal([523.25, 659.25, 783.99], 0.78, 0.07, 0.08, 37),
        "reveal_rare.wav": make_reveal([659.25, 783.99, 1_046.50], 0.96, 0.10, 0.13, 41),
        "reveal_epic.wav": make_reveal([523.25, 659.25, 783.99, 1_046.50], 1.22, 0.18, 0.18, 43),
        "reveal_legendary.wav": make_reveal([392.00, 523.25, 659.25, 783.99, 1_046.50, 1_318.51], 1.62, 0.32, 0.24, 47),
        "reveal_mythic.wav": make_reveal([261.63, 392.00, 523.25, 659.25, 783.99, 1_046.50, 1_318.51], 2.05, 0.48, 0.34, 53),
    }

    for filename, samples in sounds.items():
        write_wav(filename, samples)
        print(f"Generated {OUTPUT_DIR / filename}")


if __name__ == "__main__":
    main()

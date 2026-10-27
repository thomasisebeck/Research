from pathlib import Path
import re
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import numpy as np
import pandas as pd

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")
OUTPUT_DIR = Path("plots")

SHOW_PLOTS = True
PAUSE_DURATION = 0.2

METRIC_TITLES = {
    "runtime_ns": "Runtime (ns)",
    "cycles": "CPU Cycles",
    "instructions": "Instructions",
    "cache-misses": "Cache Misses",
    "cache-references": "Cache References",
    "branches": "Branches",
    "branch-misses": "Branch Misses",
}

LANG_ORDER = ["cpp", "rust", "zig"]
LANG_LABELS = {"cpp": "C++", "rust": "Rust", "zig": "Zig"}

# Single color per language for calibration
LANG_COLORS = {
    "cpp": "#1F4E79",   # Dark Blue
    "rust": "#D66011",  # Dark Orange
    "zig": "#2E7D32",   # Dark Green
}

# Single bar category for calibration
BAR_CATEGORIES = [
    ("calibration", "N/A", "Calibration", ""),
]

# -------------------------------------------------------------------------
# Matplotlib Setup
# -------------------------------------------------------------------------
plt.rcParams.update(
    {
        "font.family": "sans-serif",
        "font.size": 8,
        "axes.labelsize": 9,
        "axes.titlesize": 10,
        "xtick.labelsize": 9,
        "ytick.labelsize": 8,
        "figure.titlesize": 12,
        "axes.edgecolor": "#333333",
        "axes.linewidth": 0.8,
    }
)


def sanitize_filename(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_\-]", "_", str(text))


def generate_single_metric_plot(df: pd.DataFrame, metric: str, metric_title: str):
    """Generates and saves a standalone figure for a specific calibration metric."""
    mean_col = f"{metric}_mean"
    std_col = f"{metric}_std_dev"

    if mean_col not in df.columns or std_col not in df.columns:
        print(f"Skipping {metric}: missing required columns in CSV")
        return

    fig, ax = plt.subplots(figsize=(8.0, 4.8), dpi=300)

    num_languages = len(LANG_ORDER)
    num_bars_per_lang = len(BAR_CATEGORIES)

    x_indices = np.arange(num_languages)
    total_group_width = 0.40  # Narrowed slightly for single bar per group
    bar_width = total_group_width / num_bars_per_lang

    all_heights = []

    for idx, (label, setting, cat_display_name, hatch) in enumerate(BAR_CATEGORIES):
        offset = x_indices - (total_group_width / 2) + (idx + 0.5) * bar_width
        means, stds, colors = [], [], []

        for lang in LANG_ORDER:
            row = df[(df["lang"] == lang) & (df["label"] == label) & (df["setting"] == setting)]
            if not row.empty:
                m = float(row[mean_col].values[0])
                s = float(row[std_col].values[0])
                means.append(m)
                stds.append(s)
                colors.append(LANG_COLORS[lang])
                all_heights.append(m + s)
            else:
                means.append(0)
                stds.append(0)
                colors.append("#CCCCCC")

        bars = ax.bar(
            offset,
            means,
            width=bar_width * 0.85,
            yerr=stds,
            capsize=3,
            color=colors,
            edgecolor="#333333",
            linewidth=0.7,
            hatch=hatch,
            error_kw={"ecolor": "#222222", "capthick": 0.8},
        )

        for bar, mean_val, std_val in zip(bars, means, stds):
            if mean_val == 0:
                continue
            val_str = f"{mean_val:,.1f}\n±{std_val:,.1f}"
            ax.annotate(
                val_str,
                xy=(bar.get_x() + bar.get_width() / 2, bar.get_height() + std_val),
                xytext=(0, 3),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=7,
                fontweight="bold",
            )

    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=11)
    ax.set_title(f"{metric_title} (Calibration)", pad=12, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if all_heights:
        ax.set_ylim(0, max(all_heights) * 1.30)

    plt.tight_layout()

    # Filename saved with calibration prefix
    clean_metric = sanitize_filename(metric)
    filename = f"calibration_{clean_metric}.png"
    output_path = OUTPUT_DIR / filename
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Saved plot: {output_path}")

    if SHOW_PLOTS:
        plt.show()
        plt.pause(PAUSE_DURATION)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if SHOW_PLOTS:
        plt.ion()

    if CSV_PATH.is_file():
        df = pd.read_csv(CSV_PATH, na_filter=False)
    else:
        print(f"CSV file not found at {CSV_PATH}.")
        return

    print("Generating Calibration plots named by metric...")

    for metric, title in METRIC_TITLES.items():
        generate_single_metric_plot(df, metric, title)

    if SHOW_PLOTS:
        print("\nAll plots generated. Close windows or press CTRL+C to exit.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

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

LANG_COLORS = {
    "cpp": "#1F4E79",   # Dark Blue
    "rust": "#D66011",  # Dark Rust Orange
    "zig": "#2E7D32",   # Dark Green
}

RUNTIME_COLOR = "#708090"  # Slate Gray for lut_runtime
HATCH_PATTERNS = ["", "//", "\\\\", "xx", "..", "++", "OO", "**", "--", "||"]

# -------------------------------------------------------------------------
# Matplotlib Styling Setup
# -------------------------------------------------------------------------
plt.rcParams.update(
    {
        "font.family": "sans-serif",
        "font.size": 9,
        "axes.labelsize": 10,
        "axes.titlesize": 11,
        "xtick.labelsize": 10,
        "ytick.labelsize": 9,
        "figure.titlesize": 12,
        "axes.edgecolor": "#333333",
        "axes.linewidth": 0.8,
    }
)


def sanitize_filename(text: str) -> str:
    """Replaces invalid filename characters with underscores."""
    return re.sub(r"[^a-zA-Z0-9_\-]", "_", str(text))


def parse_increment_val(setting_str: str) -> float:
    """Extracts numeric value from INC_X format for proper sorting."""
    match = re.search(r"INC_([\d.]+)", str(setting_str))
    return float(match.group(1)) if match else -1.0


# -------------------------------------------------------------------------
# Plot 1: LUT Runtime Baseline
# -------------------------------------------------------------------------
def generate_lut_runtime_plot(df: pd.DataFrame, metric: str, metric_title: str):
    """Generates bar charts for LUT Runtime baseline across languages."""
    mean_col = f"{metric}_mean"
    std_col = f"{metric}_std_dev"

    if mean_col not in df.columns or std_col not in df.columns:
        return

    rt_df = df[df["label"] == "lut_runtime"].copy()
    if rt_df.empty:
        print(f"Skipping Runtime Plot ({metric}): No 'lut_runtime' label found.")
        return

    fig, ax = plt.subplots(figsize=(7, 5), dpi=300)

    x_indices = np.arange(len(LANG_ORDER))
    means, stds = [], []

    for lang in LANG_ORDER:
        row = rt_df[rt_df["lang"] == lang]
        if not row.empty:
            means.append(row[mean_col].values[0])
            stds.append(row[std_col].values[0])
        else:
            means.append(0)
            stds.append(0)

    bars = ax.bar(
        x_indices,
        means,
        width=0.5,
        yerr=stds,
        capsize=4,
        color=[LANG_COLORS[l] for l in LANG_ORDER],
        edgecolor="#333333",
        linewidth=0.8,
        error_kw={"ecolor": "#222222", "capthick": 0.8},
    )

    for bar, mean_val, std_val in zip(bars, means, stds):
        if mean_val == 0:
            continue
        ax.annotate(
            f"{mean_val:,.1f}",
            xy=(bar.get_x() + bar.get_width() / 2, bar.get_height() + std_val),
            xytext=(0, 3),
            textcoords="offset points",
            ha="center",
            va="bottom",
            fontsize=8.5,
            fontweight="bold",
        )

    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=10)
    ax.set_title(f"LUT Runtime Baseline: {metric_title}", pad=12, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if any(means):
        ax.set_ylim(0, max(m + s for m, s in zip(means, stds)) * 1.25)

    plt.tight_layout()

    filename = f"lut_runtime_{sanitize_filename(metric)}.png"
    output_path = OUTPUT_DIR / filename
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Saved plot: {output_path}")

    if SHOW_PLOTS:
        plt.show()
        plt.pause(PAUSE_DURATION)


# -------------------------------------------------------------------------
# Plot 2: LUT Comptime Increments
# -------------------------------------------------------------------------
def generate_lut_comptime_plot(df: pd.DataFrame, metric: str, metric_title: str):
    """Generates grouped bar charts for LUT Comptime increments."""
    mean_col = f"{metric}_mean"
    std_col = f"{metric}_std_dev"

    if mean_col not in df.columns or std_col not in df.columns:
        return

    ct_df = df[df["label"] == "lut_comptime"].copy()
    if ct_df.empty:
        print(f"Skipping Comptime Plot ({metric}): No 'lut_comptime' label found.")
        return

    inc_settings = sorted(
        ct_df["setting"].unique(),
        key=parse_increment_val,
        reverse=True,
    )

    fig, ax = plt.subplots(figsize=(10, 5.5), dpi=300)

    num_languages = len(LANG_ORDER)
    num_increments = len(inc_settings)

    x_indices = np.arange(num_languages)
    total_group_width = 0.8
    bar_width = total_group_width / max(num_increments, 1)

    all_heights = []
    increment_legend_elements = []

    for idx, setting in enumerate(inc_settings):
        hatch = HATCH_PATTERNS[idx % len(HATCH_PATTERNS)]
        offset = x_indices - (total_group_width / 2) + (idx + 0.5) * bar_width

        means, stds, colors = [], [], []

        for lang in LANG_ORDER:
            row = ct_df[(ct_df["lang"] == lang) & (ct_df["setting"] == setting)]
            if not row.empty:
                m = row[mean_col].values[0]
                s = row[std_col].values[0]
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
            width=bar_width * 0.9,
            yerr=stds,
            capsize=2,
            color=colors,
            edgecolor="#333333",
            linewidth=0.7,
            hatch=hatch,
            error_kw={"ecolor": "#222222", "capthick": 0.7},
        )

        for bar, mean_val, std_val in zip(bars, means, stds):
            if mean_val == 0:
                continue
            ax.annotate(
                f"{mean_val:,.1f}",
                xy=(bar.get_x() + bar.get_width() / 2, bar.get_height() + std_val),
                xytext=(0, 2),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=5.0,
                fontweight="bold",
                rotation=90,
            )

        increment_legend_elements.append(
            Patch(facecolor="#888888", edgecolor="#333333", hatch=hatch, label=setting)
        )

    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=11)
    ax.set_title(f"LUT Comptime Increments: {metric_title}", pad=12, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if all_heights:
        ax.set_ylim(0, max(all_heights) * 1.35)

    ax.legend(
        handles=increment_legend_elements,
        title="Comptime Increment",
        loc="upper left",
        frameon=True,
        fontsize=8,
        ncol=min(num_increments, 4),
    )

    plt.tight_layout()

    filename = f"lut_comptime_{sanitize_filename(metric)}.png"
    output_path = OUTPUT_DIR / filename
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Saved plot: {output_path}")

    if SHOW_PLOTS:
        plt.show()
        plt.pause(PAUSE_DURATION)


# -------------------------------------------------------------------------
# Main Execution Loop
# -------------------------------------------------------------------------
def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if SHOW_PLOTS:
        plt.ion()

    if not CSV_PATH.is_file():
        print(f"Error: CSV file not found at {CSV_PATH}")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)

    for metric, metric_title in METRIC_TITLES.items():
        generate_lut_runtime_plot(df, metric, metric_title)
        generate_lut_comptime_plot(df, metric, metric_title)

    if SHOW_PLOTS:
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

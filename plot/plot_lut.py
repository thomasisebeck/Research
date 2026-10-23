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

# Metrics to visualize and clean titles
METRIC_TITLES = {
    "runtime_ns": "Runtime (ns)",
    "cycles": "CPU Cycles",
    "instructions": "Instructions",
    "cache-misses": "Cache Misses",
    "cache-references": "Cache References",
    "branches": "Branches",
    "branch-misses": "Branch Misses",
}

# Language display ordering
LANG_ORDER = ["cpp", "rust", "zig"]
LANG_LABELS = {"cpp": "C++", "rust": "Rust", "zig": "Zig"}

# Color palette per language
LANG_COLORS = {
    "cpp": "#1F4E79",   # Dark Blue
    "rust": "#D66011",  # Dark Rust Orange
    "zig": "#2E7D32",   # Dark Green
}

RUNTIME_COLOR = "#708090"  # Slate Gray for lut_runtime

# Hatch patterns assigned across increment steps
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


def generate_lut_metric_plot(df: pd.DataFrame, metric: str, metric_title: str):
    """Generates grouped bar charts for LUT benchmark performance across increments."""
    mean_col = f"{metric}_mean"
    std_col = f"{metric}_std_dev"

    if mean_col not in df.columns or std_col not in df.columns:
        print(f"Skipping {metric}: missing required columns in CSV")
        return

    # Filter for LUT categories
    lut_df = df[df["label"].isin(["lut_comptime", "lut_runtime"])].copy()
    if lut_df.empty:
        print(f"Skipping {metric}: no LUT entries found in CSV")
        return

    # Get sorted list of unique increments
    inc_settings = sorted(
        lut_df[lut_df["label"] == "lut_comptime"]["setting"].unique(),
        key=parse_increment_val,
        reverse=True,
    )

    # Build bar categories: lut_runtime first, followed by comptime increments
    bar_categories = [("lut_runtime", "N/A", "Runtime Baseline", "")]
    for idx, setting in enumerate(inc_settings):
        hatch = HATCH_PATTERNS[idx % len(HATCH_PATTERNS)]
        bar_categories.append(("lut_comptime", setting, setting, hatch))

    fig, ax = plt.subplots(figsize=(12, 5.5), dpi=300)

    num_languages = len(LANG_ORDER)
    num_bars_per_lang = len(bar_categories)

    x_indices = np.arange(num_languages)
    total_group_width = 0.85
    bar_width = total_group_width / num_bars_per_lang

    all_heights = []

    # Render bars for each category
    for idx, (label, setting, cat_display_name, hatch) in enumerate(bar_categories):
        offset = x_indices - (total_group_width / 2) + (idx + 0.5) * bar_width

        means, stds, colors = [], [], []

        for lang in LANG_ORDER:
            row = lut_df[
                (lut_df["lang"] == lang)
                & (lut_df["label"] == label)
                & (lut_df["setting"] == setting)
            ]
            if not row.empty:
                m = row[mean_col].values[0]
                s = row[std_col].values[0]
                means.append(m)
                stds.append(s)
                colors.append(RUNTIME_COLOR if label == "lut_runtime" else LANG_COLORS[lang])
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

        # Annotations above bars
        for bar, mean_val, std_val in zip(bars, means, stds):
            if mean_val == 0:
                continue
            val_str = f"{mean_val:,.1f}"
            ax.annotate(
                val_str,
                xy=(bar.get_x() + bar.get_width() / 2, bar.get_height() + std_val),
                xytext=(0, 2),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=5.0,
                fontweight="bold",
                rotation=90,
            )

    # Axes and Formatting
    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=11)
    ax.set_title(f"LUT Evaluation: {metric_title}", pad=12, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if all_heights:
        ax.set_ylim(0, max(all_heights) * 1.35)

    # Legends: Split into Runtime vs Comptime + Increment Hatch Map
    phase_legend_elements = [
        Patch(facecolor=RUNTIME_COLOR, edgecolor="#333333", label="LUT Runtime"),
        Patch(facecolor="#555555", edgecolor="#333333", label="LUT Comptime"),
    ]

    increment_legend_elements = [
        Patch(facecolor="#CCCCCC", edgecolor="#333333", hatch=h, label=s)
        for _, s, _, h in bar_categories if s != "N/A"
    ]

    leg1 = ax.legend(
        handles=phase_legend_elements,
        title="Execution Mode",
        loc="upper left",
        frameon=True,
        fontsize=8,
    )
    ax.add_artist(leg1)

    ax.legend(
        handles=increment_legend_elements,
        title="Comptime Increment",
        loc="upper left",
        bbox_to_anchor=(0.20, 1.0),
        frameon=True,
        fontsize=7,
        ncol=2,
    )

    plt.tight_layout()

    # Save output
    clean_metric = sanitize_filename(metric)
    filename = f"combined_lut_{clean_metric}.png"
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

    # Verify CSV existence
    if not CSV_PATH.is_file():
        print(f"Error: CSV file not found at {CSV_PATH}")
        return

    # Read data
    df = pd.read_csv(CSV_PATH, na_filter=False)

    # Generate plots for all configured metrics
    for metric, metric_title in METRIC_TITLES.items():
        generate_lut_metric_plot(df, metric, metric_title)

    if SHOW_PLOTS:
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

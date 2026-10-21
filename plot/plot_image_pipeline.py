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

# Set to True for live pop-up windows; False for silent batch saving
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

# Dual-shade color map: Light/Medium for Comptime, Dark/Saturated for Runtime
COLOR_SHADES = {
    "cpp": {
        "image_pipeline_comptime": "#7CA9D4",  # Light Blue
        "image_pipeline_runtime": "#1F4E79",   # Dark Blue
    },
    "rust": {
        "image_pipeline_comptime": "#F4A261",  # Light Orange / Coral
        "image_pipeline_runtime": "#D66011",   # Dark Rust Orange
    },
    "zig": {
        "image_pipeline_comptime": "#81C784",  # Light Sage Green
        "image_pipeline_runtime": "#2E7D32",   # Dark Green
    },
}

# Bar definitions (Phase, Setting, Display Name, Hatch Pattern)
BAR_CATEGORIES = [
    ("image_pipeline_comptime", "LOW_false_false_false", "Comptime - LOW", ""),
    ("image_pipeline_comptime", "MED_true_false_true", "Comptime - MED", "//"),
    ("image_pipeline_comptime", "HIGH_true_true_true", "Comptime - HIGH", "xx"),
    ("image_pipeline_runtime", "LOW_false_false_false", "Runtime - LOW", ""),
    ("image_pipeline_runtime", "MED_true_false_true", "Runtime - MED", "//"),
    ("image_pipeline_runtime", "HIGH_true_true_true", "Runtime - HIGH", "xx"),
]

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


def generate_combined_metric_plot(df: pd.DataFrame, metric: str, metric_title: str):
    """Generates a grouped bar chart displaying 6 bars per language with phase color shading."""
    mean_col = f"{metric}_mean"
    std_col = f"{metric}_std_dev"

    if mean_col not in df.columns or std_col not in df.columns:
        print(f"Skipping {metric}: missing required columns in CSV")
        return

    fig, ax = plt.subplots(figsize=(10.5, 5.2), dpi=300)

    num_languages = len(LANG_ORDER)
    num_bars_per_lang = len(BAR_CATEGORIES)

    x_indices = np.arange(num_languages)
    total_group_width = 0.82
    bar_width = total_group_width / num_bars_per_lang

    all_heights = []

    # Render bars for each category
    for idx, (label, setting, cat_display_name, hatch) in enumerate(BAR_CATEGORIES):
        offset = x_indices - (total_group_width / 2) + (idx + 0.5) * bar_width

        means, stds, colors = [], [], []

        for lang in LANG_ORDER:
            row = df[(df["lang"] == lang) & (df["label"] == label) & (df["setting"] == setting)]
            if not row.empty:
                m = row[mean_col].values[0]
                s = row[std_col].values[0]
                means.append(m)
                stds.append(s)
                colors.append(COLOR_SHADES[lang][label])
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

        # Value annotations above each bar
        for bar, mean_val, std_val in zip(bars, means, stds):
            if mean_val == 0:
                continue
            val_str = f"{mean_val:,.1f}\n±{std_val:,.1f}"
            ax.annotate(
                val_str,
                xy=(bar.get_x() + bar.get_width() / 2, bar.get_height() + std_val),
                xytext=(0, 2),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=5.8,
                fontweight="bold",
                rotation=90 if mean_val > 100000 else 0,
            )

    # Format Axes and Labels
    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=11)
    ax.set_title(metric_title, pad=12, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    # Dynamic upper bound for annotations
    if all_heights:
        ax.set_ylim(0, max(all_heights) * 1.35)

    # Legends: Split into Phase (Color Shading) & Setting (Hatch Pattern)
    phase_legend_elements = [
        Patch(facecolor="#999999", edgecolor="#333333", label="Comptime (Lighter Shade)"),
        Patch(facecolor="#333333", edgecolor="#333333", label="Runtime (Darker Shade)"),
    ]
    
    setting_legend_elements = [
        Patch(facecolor="#CCCCCC", edgecolor="#333333", hatch="", label="LOW"),
        Patch(facecolor="#CCCCCC", edgecolor="#333333", hatch="//", label="MED"),
        Patch(facecolor="#CCCCCC", edgecolor="#333333", hatch="xx", label="HIGH"),
    ]

    leg1 = ax.legend(
        handles=phase_legend_elements,
        title="Phase Shading",
        loc="upper left",
        frameon=True,
        fontsize=8,
    )
    ax.add_artist(leg1)

    ax.legend(
        handles=setting_legend_elements,
        title="Setting",
        loc="upper left",
        bbox_to_anchor=(0.24, 1.0),
        frameon=True,
        fontsize=8,
    )

    plt.tight_layout()

    # Save output
    clean_metric = sanitize_filename(metric)
    filename = f"combined_image_pipeline_{clean_metric}.png"
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
        print(f"CSV file not found at {CSV_PATH}. Please ensure the file exists.")
        return

    print("Generating color-shaded combined plots across phases and settings...")

    for metric, title in METRIC_TITLES.items():
        generate_combined_metric_plot(df, metric, title)

    if SHOW_PLOTS:
        print("\nAll plots generated. Close window windows or press CTRL+C to exit.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

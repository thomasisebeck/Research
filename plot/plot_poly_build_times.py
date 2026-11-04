import re
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("build_times_all.csv")
OUTPUT_DIR = Path("plots_build_time")

SHOW_PLOTS = True
PAUSE_DURATION = 0.2

LANG_ORDER = ["cpp", "rust", "zig"]
LANG_LABELS = {"cpp": "C++", "rust": "Rust", "zig": "Zig"}

# Darker, desaturated palette
COLOR_MAPS = {
    "cpp": {
        "cold_user": "#2B4053",  # Desaturated Dark Blue
        "cold_sys": "#5C6B73",   # Muted Slate
        "hot_user": "#4A6274",    # Mid Slate Blue
        "hot_sys": "#8D99AE",     # Soft Grey-Blue
    },
    "rust": {
        "cold_user": "#7A3E21",  # Desaturated Dark Rust
        "cold_sys": "#8C6A58",   # Muted Warm Grey
        "hot_user": "#9E5A33",    # Mid Muted Orange
        "hot_sys": "#B8927C",     # Soft Grey-Orange
    },
    "zig": {
        "cold_user": "#274E36",  # Desaturated Dark Forest Green
        "cold_sys": "#526E5C",   # Muted Sage
        "hot_user": "#3C6E4D",    # Mid Soft Green
        "hot_sys": "#8FA89B",     # Soft Grey-Green
    },
}

# -------------------------------------------------------------------------
# Matplotlib Setup
# -------------------------------------------------------------------------
plt.rcParams.update(
    {
        "font.family": "sans-serif",
        "font.size": 8,
        "axes.labelsize": 10,
        "axes.titlesize": 12,
        "xtick.labelsize": 10,
        "ytick.labelsize": 9,
        "figure.titlesize": 13,
        "axes.edgecolor": "#333333",
        "axes.linewidth": 0.8,
    }
)


def plot_poly_comparison(df_overhead: pd.DataFrame, build_type: str = "cold"):
    """
    Plots poly_dyn vs poly_stat side-by-side on a single figure for either 'cold' or 'hot' builds.
    
    Parameters:
        df_overhead (pd.DataFrame): DataFrame containing calculated overhead metrics relative to baseline.
        build_type (str): Either 'cold' or 'hot'.
    """
    fig, ax = plt.subplots(figsize=(10.0, 5.5), dpi=300)

    num_languages = len(LANG_ORDER)
    x_indices = np.arange(num_languages)

    # 4 bars per language cluster: [dyn_cold, stat_cold] or [dyn_hot, stat_hot]
    # To keep it clear, we compare poly_dyn vs poly_stat for the selected build regime (Cold or Hot)
    bar_width = 0.18
    spacing = 0.04

    labels_to_compare = ["poly_dyn", "poly_stat"]
    label_display_names = {"poly_dyn": "Dynamic Dispatch", "poly_stat": "Static Dispatch"}

    all_max_heights = []

    for lang_idx, lang in enumerate(LANG_ORDER):
        colors = COLOR_MAPS[lang]

        for label_idx, label in enumerate(labels_to_compare):
            row = df_overhead[(df_overhead["lang"] == lang) & (df_overhead["label"] == label)]
            if row.empty:
                continue

            row_data = row.iloc[0]

            # Extract user/sys/real metrics for chosen regime
            user_mean = max(0.0, float(row_data[f"{build_type}_user_mean"]))
            sys_mean = max(0.0, float(row_data[f"{build_type}_sys_mean"]))
            real_mean = float(row_data[f"{build_type}_real_mean"])
            real_std = float(row_data[f"{build_type}_real_std_dev"])

            # Offset position within language group
            offset = (label_idx - 0.5) * (bar_width + spacing)
            x_pos = x_indices[lang_idx] + offset

            # Select primary & secondary color shades based on dispatch type
            # Use main metric color for poly_dyn and slightly lighter/patterned or solid for stat
            c_user = colors[f"{build_type}_user"]
            c_sys = colors[f"{build_type}_sys"]
            alpha = 1.0 if label == "poly_dyn" else 0.65
            hatch = "" if label == "poly_dyn" else "//"

            # Stacked user + sys
            ax.bar(
                x_pos,
                user_mean,
                width=bar_width,
                color=c_user,
                alpha=alpha,
                hatch=hatch,
                edgecolor="#111111",
                linewidth=0.8,
                zorder=2,
                label=f"{label_display_names[label]} ($T_{{\\mathrm{{user}}}}$)" if lang_idx == 0 else "",
            )
            ax.bar(
                x_pos,
                sys_mean,
                bottom=user_mean,
                width=bar_width,
                color=c_sys,
                alpha=alpha,
                hatch=hatch,
                edgecolor="#111111",
                linewidth=0.8,
                zorder=2,
                label=f"{label_display_names[label]} ($T_{{\\mathrm{{sys}}}}$)" if lang_idx == 0 else "",
            )

            # Real-time marker and error bar
            ax.plot(
                [x_pos - (bar_width * 0.45), x_pos + (bar_width * 0.45)],
                [real_mean, real_mean],
                color="black",
                linewidth=2.2,
                zorder=4,
            )
            ax.errorbar(
                x_pos,
                real_mean,
                yerr=real_std,
                fmt="o",
                color="black",
                ecolor="black",
                capsize=3,
                capthick=1.0,
                markersize=3.5,
                zorder=5,
            )

            # Annotate real-time overhead value
            val_str = f"{real_mean:.2f}s\n±{real_std:.2f}s"
            ax.annotate(
                val_str,
                xy=(x_pos, max(0.0, real_mean)),
                xytext=(0, 5),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=7.0,
                fontweight="bold",
            )

            all_max_heights.append(real_mean + real_std)

    # Sub-category x-axis labeling (poly_dyn vs poly_stat under each language)
    sub_labels = []
    sub_positions = []
    for lang_idx in range(num_languages):
        sub_positions.extend([x_indices[lang_idx] - 0.5 * (bar_width + spacing), 
                              x_indices[lang_idx] + 0.5 * (bar_width + spacing)])
        sub_labels.extend(["Dynamic", "Static"])

    # Secondary x-ticks for dispatch sub-type
    ax.set_xticks(sub_positions)
    ax.set_xticklabels(sub_labels, fontsize=8, color="#444444")

    # Major x-ticks for Language names placed below sub-labels
    for lang_idx, lang in enumerate(LANG_ORDER):
        ax.text(
            x_indices[lang_idx],
            -0.12,
            LANG_LABELS[lang],
            transform=ax.get_xaxis_transform(),
            ha="center",
            va="top",
            fontweight="bold",
            fontsize=11,
        )

    ax.set_ylabel("Overhead Time (seconds)", fontweight="bold", fontsize=10)
    ax.set_title(
        f"Build Time Overhead Comparison: Polymorphism ({build_type.capitalize()} Build)",
        pad=16,
        fontweight="bold",
    )
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if all_max_heights:
        max_h = max(all_max_heights)
        ax.set_ylim(min(0.0, min(all_max_heights) * 1.1), max_h * 1.25 if max_h > 0 else 1.0)

    # Deduplicate legend entries
    handles, labels = ax.get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    ax.legend(by_label.values(), by_label.keys(), loc="upper left", ncol=2, framealpha=0.9, fontsize=8)

    plt.tight_layout()

    output_path = OUTPUT_DIR / f"overhead_poly_dyn_vs_stat_{build_type}.png"
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Saved side-by-side plot: {output_path}")

    if SHOW_PLOTS:
        plt.show()
        plt.pause(PAUSE_DURATION)


def calculate_overhead_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Computes baseline-subtracted overheads and propagates variance."""
    df_base = df[df["label"] == "build_offset"].copy()
    baseline_dict = {row["lang"]: row.to_dict() for _, row in df_base.iterrows()}

    time_metrics = ["cold_real", "cold_user", "cold_sys", "hot_real", "hot_user", "hot_sys"]
    df_exp = df[df["label"].isin(["poly_dyn", "poly_stat"])].copy()
    overhead_rows = []

    for _, row in df_exp.iterrows():
        lang = row["lang"]
        if lang not in baseline_dict:
            continue

        base_row = baseline_dict[lang]
        overhead_entry = {"lang": lang, "label": row["label"], "setting": row["setting"]}

        for metric in time_metrics:
            exp_mean = float(row[f"{metric}_mean"])
            exp_var = float(row[f"{metric}_variance"])
            base_mean = float(base_row[f"{metric}_mean"])
            base_var = float(base_row[f"{metric}_variance"])

            overhead_entry[f"{metric}_mean"] = exp_mean - base_mean
            combined_var = exp_var + base_var
            overhead_entry[f"{metric}_variance"] = combined_var
            overhead_entry[f"{metric}_std_dev"] = np.sqrt(combined_var)

        overhead_rows.append(overhead_entry)

    return pd.DataFrame(overhead_rows)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if SHOW_PLOTS:
        plt.ion()

    if CSV_PATH.is_file():
        df = pd.read_csv(CSV_PATH, na_filter=False)
    else:
        print(f"CSV file not found at {CSV_PATH}.")
        return

    df_overhead = calculate_overhead_dataframe(df)

    # Plot Cold Build comparison side-by-side
    plot_poly_comparison(df_overhead, build_type="cold")

    # Plot Hot Build comparison side-by-side
    plot_poly_comparison(df_overhead, build_type="hot")

    if SHOW_PLOTS:
        print("\nAll plots generated. Close windows or press CTRL+C to exit.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

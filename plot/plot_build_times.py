from pathlib import Path
import re
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
        "hot_user": "#4A6274",   # Mid Slate Blue
        "hot_sys": "#8D99AE",    # Soft Grey-Blue
    },
    "rust": {
        "cold_user": "#7A3E21",  # Desaturated Dark Rust
        "cold_sys": "#8C6A58",   # Muted Warm Grey
        "hot_user": "#9E5A33",   # Mid Muted Orange
        "hot_sys": "#B8927C",    # Soft Grey-Orange
    },
    "zig": {
        "cold_user": "#274E36",  # Desaturated Dark Forest Green
        "cold_sys": "#526E5C",   # Muted Sage
        "hot_user": "#3C6E4D",   # Mid Soft Green
        "hot_sys": "#8FA89B",    # Soft Grey-Green
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


def sanitize_filename(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_\-]", "_", str(text))


def plot_stacked_build_time(
    df_subset: pd.DataFrame,
    title_suffix: str,
    filename_prefix: str,
    is_overhead: bool = False,
):
    """Generates a stacked build time plot (Cold vs Hot) with matched error propagation."""
    fig, ax = plt.subplots(figsize=(9.0, 5.0), dpi=300)

    num_languages = len(LANG_ORDER)
    x_indices = np.arange(num_languages)
    group_width = 0.50
    bar_width = group_width / 2.0

    all_max_heights = []

    for lang_idx, lang in enumerate(LANG_ORDER):
        row = df_subset[df_subset["lang"] == lang]
        if row.empty:
            continue

        row_data = row.iloc[0]

        # Extract fully adjusted components (non-negative floor for plotting stability)
        cold_user = max(0.0, float(row_data["cold_user_mean"]))
        cold_sys = max(0.0, float(row_data["cold_sys_mean"]))
        cold_real = float(row_data["cold_real_mean"])
        cold_real_std = float(row_data["cold_real_std_dev"])

        hot_user = max(0.0, float(row_data["hot_user_mean"]))
        hot_sys = max(0.0, float(row_data["hot_sys_mean"]))
        hot_real = float(row_data["hot_real_mean"])
        hot_real_std = float(row_data["hot_real_std_dev"])

        colors = COLOR_MAPS[lang]

        x_cold = x_indices[lang_idx] - (bar_width / 2.0) - 0.02
        x_hot = x_indices[lang_idx] + (bar_width / 2.0) + 0.02

        # 1. Cold Stacked Bar (Delta User + Delta Sys)
        ax.bar(
            x_cold,
            cold_user,
            width=bar_width * 0.9,
            color=colors["cold_user"],
            edgecolor="#111111",
            linewidth=0.7,
            zorder=2,
            label="Cold $T_{\\mathrm{user}}$" if lang_idx == 0 else "",
        )
        ax.bar(
            x_cold,
            cold_sys,
            bottom=cold_user,
            width=bar_width * 0.9,
            color=colors["cold_sys"],
            edgecolor="#111111",
            linewidth=0.7,
            zorder=2,
            label="Cold $T_{\\mathrm{sys}}$" if lang_idx == 0 else "",
        )

        # 2. Hot Stacked Bar (Delta User + Delta Sys)
        ax.bar(
            x_hot,
            hot_user,
            width=bar_width * 0.9,
            color=colors["hot_user"],
            edgecolor="#111111",
            linewidth=0.7,
            zorder=2,
            label="Hot $T_{\\mathrm{user}}$" if lang_idx == 0 else "",
        )
        ax.bar(
            x_hot,
            hot_sys,
            bottom=hot_user,
            width=bar_width * 0.9,
            color=colors["hot_sys"],
            edgecolor="#111111",
            linewidth=0.7,
            zorder=2,
            label="Hot $T_{\\mathrm{sys}}$" if lang_idx == 0 else "",
        )

        # 3. Real-time Indicators and propagated error bounds
        for x_pos, real_val, real_std in [(x_cold, cold_real, cold_real_std), (x_hot, hot_real, hot_real_std)]:
            ax.plot(
                [x_pos - (bar_width * 0.45), x_pos + (bar_width * 0.45)],
                [real_val, real_val],
                color="black",
                linewidth=2.5,
                zorder=4,
                label="$T_{\\mathrm{real}}$ (Real Time)" if (lang_idx == 0 and x_pos == x_cold) else "",
            )
            ax.errorbar(
                x_pos,
                real_val,
                yerr=real_std,
                fmt="o",
                color="black",
                ecolor="black",
                capsize=3,
                capthick=1.0,
                markersize=4,
                zorder=5,
            )

            val_str = f"{real_val:.2f}s ± {real_std:.2f}s"
            ax.annotate(
                val_str,
                xy=(x_pos, max(0.0, real_val)),
                xytext=(0, 6),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=7.5,
                fontweight="bold",
            )

        all_max_heights.extend([cold_real + cold_real_std, hot_real + hot_real_std])

    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=11)

    ylabel = "Overhead Time (seconds)" if is_overhead else "Time (seconds)"
    title_prefix = "Build Time Overhead (Relative to Baseline)" if is_overhead else "Build Time Baseline"

    ax.set_ylabel(ylabel, fontweight="bold", fontsize=10)
    ax.set_title(f"{title_prefix}: {title_suffix}", pad=14, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if all_max_heights:
        max_h = max(all_max_heights)
        ax.set_ylim(0, max_h * 1.22 if max_h > 0 else 1.0)

    ax.legend(loc="upper left", ncol=2, framealpha=0.9, fontsize=8)

    plt.tight_layout()

    filename = f"{'overhead' if is_overhead else 'baseline'}_{sanitize_filename(filename_prefix)}.png"
    output_path = OUTPUT_DIR / filename
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Saved plot: {output_path}")

    if SHOW_PLOTS:
        plt.show()
        plt.pause(PAUSE_DURATION)


def calculate_and_plot_overhead(df: pd.DataFrame):
    # Extract baseline values (`label == 'build_offset'`)
    df_base = df[df["label"] == "build_offset"].copy()

    if df_base.empty:
        print("Error: No 'build_offset' baseline entries found in CSV.")
        return

    print("\n" + "=" * 60)
    print("CALCULATED BASELINE BUILD TIMES (Control Baseline)")
    print("=" * 60)

    baseline_dict = {}

    for _, row in df_base.iterrows():
        lang = row["lang"]
        baseline_dict[lang] = row.to_dict()

        print(f"\nLanguage: {LANG_LABELS.get(lang, lang)}")
        print(f"  Cold Real Time : {row['cold_real_mean']:.2f}s ± {row['cold_real_std_dev']:.2f}s (Var: {row['cold_real_variance']:.4f})")
        print(f"  Cold User Time : {row['cold_user_mean']:.2f}s ± {row['cold_user_std_dev']:.2f}s (Var: {row['cold_user_variance']:.4f})")
        print(f"  Cold Sys Time  : {row['cold_sys_mean']:.2f}s ± {row['cold_sys_std_dev']:.2f}s (Var: {row['cold_sys_variance']:.4f})")
        print(f"  Hot Real Time  : {row['hot_real_mean']:.2f}s ± {row['hot_real_std_dev']:.2f}s (Var: {row['hot_real_variance']:.4f})")
        print(f"  Hot User Time  : {row['hot_user_mean']:.2f}s ± {row['hot_user_std_dev']:.2f}s (Var: {row['hot_user_variance']:.4f})")
        print(f"  Hot Sys Time   : {row['hot_sys_mean']:.2f}s ± {row['hot_sys_std_dev']:.2f}s (Var: {row['hot_sys_variance']:.4f})")

    print("\n" + "=" * 60)

    # Plot control baseline
    plot_stacked_build_time(
        df_subset=df_base,
        title_suffix="Minimal Executable Control",
        filename_prefix="build_offset",
        is_overhead=False,
    )

    # Compute component-wise differential build overheads + propagated variance
    time_metrics = ["cold_real", "cold_user", "cold_sys", "hot_real", "hot_user", "hot_sys"]

    df_exp = df[df["label"] != "build_offset"].copy()
    overhead_rows = []

    for _, row in df_exp.iterrows():
        lang = row["lang"]
        if lang not in baseline_dict:
            continue

        base_row = baseline_dict[lang]
        overhead_entry = {
            "lang": lang,
            "label": row["label"],
            "setting": row["setting"],
        }

        # Component-level subtraction + variance addition: std_diff = sqrt(var_exp + var_base)
        for metric in time_metrics:
            exp_mean = float(row[f"{metric}_mean"])
            exp_var = float(row[f"{metric}_variance"])

            base_mean = float(base_row[f"{metric}_mean"])
            base_var = float(base_row[f"{metric}_variance"])

            # Subtract baseline component mean
            diff_mean = exp_mean - base_mean

            # Propagate combined variance
            combined_var = exp_var + base_var
            combined_std = np.sqrt(combined_var)

            overhead_entry[f"{metric}_mean"] = diff_mean
            overhead_entry[f"{metric}_variance"] = combined_var
            overhead_entry[f"{metric}_std_dev"] = combined_std

        overhead_rows.append(overhead_entry)

    df_overhead = pd.DataFrame(overhead_rows)

    # Plot differential overheads
    labels = df_overhead["label"].unique()

    for label in labels:
        df_label = df_overhead[df_overhead["label"] == label]
        settings = df_label["setting"].unique()

        for setting in settings:
            df_subset = df_label[df_label["setting"] == setting]

            title_suffix = f"{label} ({setting})" if setting != "N/A" else f"{label}"
            filename_prefix = f"{label}_{setting}" if setting != "N/A" else f"{label}"

            plot_stacked_build_time(
                df_subset=df_subset,
                title_suffix=title_suffix,
                filename_prefix=filename_prefix,
                is_overhead=True,
            )


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if SHOW_PLOTS:
        plt.ion()

    if CSV_PATH.is_file():
        df = pd.read_csv(CSV_PATH, na_filter=False)
    else:
        print(f"CSV file not found at {CSV_PATH}.")
        return

    calculate_and_plot_overhead(df)

    if SHOW_PLOTS:
        print("\nAll plots generated. Close windows or press CTRL+C to exit.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

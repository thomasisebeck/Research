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

# Workload configurations mapping setting strings to clean category labels
SETTINGS_MAP = [
    ("LOW_false_false_false", "LOW"),
    ("MED_true_false_true", "MED"),
    ("HIGH_true_true_true", "HIGH"),
]

# Color palette matching the textured sweep style
COLOR_MAPS = {
    "cpp": {
        "cold_user": "#1F4E79",  # Dark Blue
        "hot_user": "#3B75A4",   # Lighter Blue (Hatched)
    },
    "rust": {
        "cold_user": "#A63603",  # Dark Rust
        "hot_user": "#D66011",   # Lighter Rust (Hatched)
    },
    "zig": {
        "cold_user": "#274E36",  # Dark Forest Green
        "hot_user": "#3C6E4D",   # Lighter Green (Hatched)
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
        "xtick.labelsize": 9,
        "ytick.labelsize": 9,
        "figure.titlesize": 13,
        "axes.edgecolor": "#333333",
        "axes.linewidth": 0.8,
    }
)


def plot_image_pipeline_grouped(
    df: pd.DataFrame,
    pipeline_type: str,  # "image_pipeline_comptime" or "image_pipeline_runtime"
    plot_title: str,
    output_filename: str,
):
    """
    Plots T_user CPU overhead for Cold (solid) and Hot (hatched) builds
    across all image pipeline workload settings (LOW, MED, HIGH) on the same X-axis.
    """
    df_base = df[df["label"] == "build_offset"].set_index("lang")
    df_pipe = df[df["label"] == pipeline_type]

    if df_base.empty:
        print("Error: Missing 'build_offset' baseline entries.")
        return

    categories = [label for _, label in SETTINGS_MAP]
    num_categories = len(categories)
    num_langs = len(LANG_ORDER)

    group_x_indices = np.arange(num_categories)
    total_group_width = 0.85
    lang_slot_width = total_group_width / num_langs
    bar_width = lang_slot_width * 0.42

    fig, ax = plt.subplots(figsize=(12.0, 6.0), dpi=300)

    global_max_y = 0.0

    for lang_idx, lang in enumerate(LANG_ORDER):
        if lang not in df_base.index:
            continue

        base_row = df_base.loc[lang]
        df_lang_pipe = df_pipe[df_pipe["lang"] == lang]

        # Center language sub-groups within each workload setting category
        lang_center_x = group_x_indices - (total_group_width / 2.0) + (lang_idx + 0.5) * lang_slot_width
        x_cold = lang_center_x - (bar_width / 2.0) - 0.01
        x_hot = lang_center_x + (bar_width / 2.0) + 0.01

        # Extract T_user mean difference and propagated error: sqrt(var_exp + var_base)
        def collect_user_data(build_state):
            u_vals, u_stds = [], []

            base_u_mean = float(base_row[f"{build_state}_user_mean"])
            base_u_var = float(base_row[f"{build_state}_user_variance"])

            for setting_key, _ in SETTINGS_MAP:
                row_match = df_lang_pipe[df_lang_pipe["setting"] == setting_key]
                if not row_match.empty:
                    exp_row = row_match.iloc[0]
                    u_mean = float(exp_row[f"{build_state}_user_mean"])
                    u_var = float(exp_row[f"{build_state}_user_variance"])

                    diff_mean = max(0.0, u_mean - base_u_mean)
                    diff_std = np.sqrt(u_var + base_u_var)
                else:
                    diff_mean, diff_std = 0.0, 0.0

                u_vals.append(diff_mean)
                u_stds.append(diff_std)

            return u_vals, u_stds

        c_u, c_std = collect_user_data("cold")
        h_u, h_std = collect_user_data("hot")

        colors = COLOR_MAPS[lang]

        # 1. Cold T_user Bars (Solid)
        ax.bar(
            x_cold,
            c_u,
            width=bar_width,
            color=colors["cold_user"],
            edgecolor="#111111",
            linewidth=0.6,
            zorder=2,
            label=f"{LANG_LABELS[lang]} Cold $T_\\mathrm{{user}}$",
        )

        # 2. Hot T_user Bars (Hatched)
        ax.bar(
            x_hot,
            h_u,
            width=bar_width,
            color=colors["hot_user"],
            edgecolor="#111111",
            hatch="//",
            linewidth=0.6,
            zorder=2,
            label=f"{LANG_LABELS[lang]} Hot $T_\\mathrm{{user}}$",
        )

        # 3. Error Bars and Text Annotations
        for x_pos_arr, u_vals, u_stds in [(x_cold, c_u, c_std), (x_hot, h_u, h_std)]:
            for x_pos, val, std in zip(x_pos_arr, u_vals, u_stds):
                ax.errorbar(
                    x_pos,
                    val,
                    yerr=std,
                    fmt="none",
                    ecolor="black",
                    capsize=2.0,
                    capthick=0.7,
                    zorder=5,
                )

                top_pt = val + std
                if top_pt > global_max_y:
                    global_max_y = top_pt

                val_str = f"{val:.2f}s\n±{std:.2f}s" if val >= 0.01 else "0.00s"

                ax.annotate(
                    val_str,
                    xy=(x_pos, val),
                    xytext=(0, 2),
                    textcoords="offset points",
                    ha="center",
                    va="bottom",
                    fontsize=5.5,
                    fontweight="bold",
                    rotation=30,
                )

    ax.set_xticks(group_x_indices)
    ax.set_xticklabels([f"Setting: {cat}" for cat in categories], fontweight="bold", fontsize=10)
    ax.set_ylabel("Compiler CPU Overhead ($T_\\mathrm{user}$ in seconds)", fontweight="bold", fontsize=10)
    ax.set_title(plot_title, pad=15, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    # Set bottom Y-limit strictly at 0 for a clean baseline
    ax.set_ylim(0.0, global_max_y * 1.15)

    # Deduplicated legend
    handles, labels = ax.get_legend_handles_labels()
    by_label = dict(zip(labels, handles))
    ax.legend(by_label.values(), by_label.keys(), loc="upper left", ncol=3, framealpha=0.9, fontsize=8)

    plt.tight_layout()

    out_file = OUTPUT_DIR / f"{output_filename}.png"
    plt.savefig(out_file, dpi=300, bbox_inches="tight")
    print(f"Saved plot: {out_file}")

    if SHOW_PLOTS:
        plt.show()
        plt.pause(PAUSE_DURATION)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if SHOW_PLOTS:
        plt.ion()

    if not CSV_PATH.is_file():
        print(f"CSV file not found at {CSV_PATH}")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)

    # 1. Compile-Time Image Pipeline (LOW, MED, HIGH on single axis)
    plot_image_pipeline_grouped(
        df=df,
        pipeline_type="image_pipeline_comptime",
        plot_title="Compile-Time Image Pipeline Build Overhead Across Workload Settings ($T_\\mathrm{user}$ CPU Time)",
        output_filename="image_pipeline_comptime_all_settings",
    )

    # 2. Runtime Image Pipeline (LOW, MED, HIGH on single axis)
    plot_image_pipeline_grouped(
        df=df,
        pipeline_type="image_pipeline_runtime",
        plot_title="Runtime Image Pipeline Build Overhead Across Workload Settings ($T_\\mathrm{user}$ CPU Time)",
        output_filename="image_pipeline_runtime_all_settings",
    )

    if SHOW_PLOTS:
        print("\nAll plots generated successfully. Close windows or press CTRL+C to exit.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

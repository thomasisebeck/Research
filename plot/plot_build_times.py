from pathlib import Path
import re
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")  # Update to build_times.csv if separate
OUTPUT_DIR = Path("plots_build_time")

SHOW_PLOTS = True
PAUSE_DURATION = 0.2

LANG_ORDER = ["cpp", "rust", "zig"]
LANG_LABELS = {"cpp": "C++", "rust": "Rust", "zig": "Zig"}

# Color palette definition per language & state
COLOR_MAPS = {
    "cpp": {
        "cold_user": "#1F4E79",  # Dark Blue
        "cold_sys": "#A63603",   # Dark Red-Orange
        "hot_user": "#6BAED6",   # Light Blue
        "hot_sys": "#FDBE85",    # Soft Gold
    },
    "rust": {
        "cold_user": "#D66011",  # Dark Orange
        "cold_sys": "#A63603",   # Dark Red-Orange
        "hot_user": "#FDAE6B",  # Light Orange
        "hot_sys": "#FDBE85",    # Soft Gold
    },
    "zig": {
        "cold_user": "#2E7D32",  # Dark Green
        "cold_sys": "#A63603",   # Dark Red-Orange
        "hot_user": "#A1D99B",  # Light Green
        "hot_sys": "#FDBE85",    # Soft Gold
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


def plot_build_time_category(df_subset: pd.DataFrame, title_suffix: str, filename_prefix: str):
    """Generates a stacked build time plot (Cold vs Hot) for a given scenario subset."""
    fig, ax = plt.subplots(figsize=(9.0, 5.0), dpi=300)

    num_languages = len(LANG_ORDER)
    x_indices = np.arange(num_languages)
    group_width = 0.50
    bar_width = group_width / 2.0  # Cold and Hot bars side-by-side

    all_max_heights = []

    for lang_idx, lang in enumerate(LANG_ORDER):
        row = df_subset[df_subset["lang"] == lang]
        if row.empty:
            continue

        row_data = row.iloc[0]

        # Fetch Cold parameters
        cold_user = float(row_data["cold_user_mean"])
        cold_sys = float(row_data["cold_sys_mean"])
        cold_real = float(row_data["cold_real_mean"])
        cold_real_std = float(row_data["cold_real_std_dev"])

        # Fetch Hot parameters
        hot_user = float(row_data["hot_user_mean"])
        hot_sys = float(row_data["hot_sys_mean"])
        hot_real = float(row_data["hot_real_mean"])
        hot_real_std = float(row_data["hot_real_std_dev"])

        colors = COLOR_MAPS[lang]

        # X-offsets for Cold (left) and Hot (right) bars
        x_cold = x_indices[lang_idx] - (bar_width / 2.0) - 0.02
        x_hot = x_indices[lang_idx] + (bar_width / 2.0) + 0.02

        # 1. Stacked Bar: Cold Build (User + Sys)
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

        # 2. Stacked Bar: Hot Build (User + Sys)
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

        # 3. Real-Time Overlay ($T_{real}$) with Error Line
        for x_pos, real_val, real_std in [(x_cold, cold_real, cold_real_std), (x_hot, hot_real, hot_real_std)]:
            # T_real Horizontal bar cap + error point
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

            # Value Annotations (e.g. "10.87s ± 0.04s")
            val_str = f"{real_val:.2f}s ± {real_std:.2f}s"
            ax.annotate(
                val_str,
                xy=(x_pos, real_val),
                xytext=(0, 6),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=7.5,
                fontweight="bold",
            )

        all_max_heights.extend([cold_real + cold_real_std, hot_real + hot_real_std])

    # Styling and Labels
    ax.set_xticks(x_indices)
    ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=11)
    ax.set_ylabel("Time (seconds)", fontweight="bold", fontsize=10)
    ax.set_title(f"Build Time: {title_suffix}", pad=14, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    if all_max_heights:
        ax.set_ylim(0, max(all_max_heights) * 1.18)

    ax.legend(loc="upper left", ncol=2, framealpha=0.9, fontsize=8)

    plt.tight_layout()

    filename = f"build_time_{sanitize_filename(filename_prefix)}.png"
    output_path = OUTPUT_DIR / filename
    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    print(f"Saved build time plot: {output_path}")

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

    print("Generating Build Time plots grouped by scenario...")

    # Iterate over unique label/setting combinations in the CSV
    labels = df["label"].unique()

    for label in labels:
        df_label = df[df["label"] == label]
        settings = df_label["setting"].unique()

        for setting in settings:
            df_subset = df_label[df_label["setting"] == setting]

            title_suffix = f"{label} ({setting})" if setting != "N/A" else f"{label}"
            filename_prefix = f"{label}_{setting}" if setting != "N/A" else f"{label}"

            plot_build_time_category(df_subset, title_suffix, filename_prefix)

    if SHOW_PLOTS:
        print("\nAll plots generated. Close windows or press CTRL+C to exit.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()
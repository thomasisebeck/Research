from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
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

# Color palette matching reference plot (dark for cold, lighter/hatched for hot)
COLOR_MAPS = {
    "cpp": {
        "cold_user": "#2B4053",  # Dark Slate Blue
        "cold_sys": "#5C6B73",   # Muted Slate
        "hot_user": "#4A6274",   # Lighter Slate Blue
        "hot_sys": "#8D99AE",    # Soft Grey-Blue
    },
    "rust": {
        "cold_user": "#7A3E21",  # Dark Rust
        "cold_sys": "#8C6A58",   # Muted Warm Grey
        "hot_user": "#9E5A33",   # Lighter Rust
        "hot_sys": "#B8927C",    # Soft Grey-Orange
    },
    "zig": {
        "cold_user": "#274E36",  # Dark Forest Green
        "cold_sys": "#526E5C",   # Muted Sage
        "hot_user": "#3C6E4D",   # Lighter Green
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
        "xtick.labelsize": 8.5,
        "ytick.labelsize": 9,
        "figure.titlesize": 13,
        "axes.edgecolor": "#333333",
        "axes.linewidth": 0.8,
    }
)


def plot_poly_interleaved_by_lang(df_overhead: pd.DataFrame):
    """
    Plots poly_dyn vs poly_stat interleaved as Cold/Hot pairs under each language:
    [Cold Dyn, Hot Dyn, Cold Stat, Hot Stat] across C++, Rust, and Zig.
    """
    fig, ax = plt.subplots(figsize=(14.0, 6.2), dpi=300)

    num_languages = len(LANG_ORDER)
    group_x_indices = np.arange(num_languages)

    # Interleaved bar layout per language: (dispatch_label, build_state)
    interleaved_slots = [
        ("poly_dyn", "cold", "Dyn (Cold)"),
        ("poly_dyn", "hot", "Dyn (Hot)"),
        ("poly_stat", "cold", "Stat (Cold)"),
        ("poly_stat", "hot", "Stat (Hot)"),
    ]
    num_bars_per_lang = len(interleaved_slots)  # 4 bars per language

    total_group_width = 0.72
    bar_slot_width = total_group_width / num_bars_per_lang
    bar_width = bar_slot_width * 0.82

    global_max_y = 0.0

    all_sub_positions = []
    all_sub_labels = []

    for lang_idx, lang in enumerate(LANG_ORDER):
        colors = COLOR_MAPS[lang]
        lang_center_x = group_x_indices[lang_idx]

        for slot_idx, (label, build_state, sub_label) in enumerate(interleaved_slots):
            row = df_overhead[(df_overhead["lang"] == lang) & (df_overhead["label"] == label)]
            if row.empty:
                continue

            row_data = row.iloc[0]

            u_mean = float(row_data[f"{build_state}_user_mean"])
            s_mean = float(row_data[f"{build_state}_sys_mean"])
            r_mean = float(row_data[f"{build_state}_real_mean"])
            r_std = float(row_data[f"{build_state}_real_std_dev"])

            diff_u = max(0.0, u_mean)
            diff_s = max(0.0, s_mean)

            # Offset position relative to language group center
            offset = (slot_idx - 1.5) * bar_slot_width
            x_pos = lang_center_x + offset

            all_sub_positions.append(x_pos)
            all_sub_labels.append(sub_label)

            c_user = colors[f"{build_state}_user"]
            c_sys = colors[f"{build_state}_sys"]
            hatch = "" if build_state == "cold" else "//"

            # 1. Stacked User + Sys Bars
            ax.bar(
                x_pos,
                diff_u,
                width=bar_width,
                color=c_user,
                edgecolor="#111111",
                hatch=hatch,
                linewidth=0.6,
                zorder=2,
            )
            ax.bar(
                x_pos,
                diff_s,
                bottom=diff_u,
                width=bar_width,
                color=c_sys,
                edgecolor="#111111",
                hatch=hatch,
                linewidth=0.6,
                zorder=2,
            )

            # 2. Clamped Real-Time Marker & Error Bar
            if r_mean <= 0.0:
                disp_r = 0.0
                upper_err = 0.0
                lower_err = 0.0
            else:
                disp_r = r_mean
                upper_err = r_std
                lower_err = min(r_std, disp_r)

            ax.plot(
                [x_pos - (bar_width * 0.42), x_pos + (bar_width * 0.42)],
                [disp_r, disp_r],
                color="black",
                linewidth=2.0,
                zorder=4,
            )
            ax.errorbar(
                x_pos,
                disp_r,
                yerr=[[lower_err], [upper_err]],
                fmt="none",
                ecolor="black",
                capsize=2.2,
                capthick=0.7,
                zorder=5,
            )

            top_pt = max(diff_u + diff_s, disp_r + upper_err)
            if top_pt > global_max_y:
                global_max_y = top_pt

            # 3. Floating annotation value
            val_str = f"{r_mean:.2f}s\n±{r_std:.2f}s" if r_mean >= 0.01 else "0.00s"
            ax.annotate(
                val_str,
                xy=(x_pos, top_pt),
                xytext=(0, 3),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=5.5,
                fontweight="bold",
                rotation=30,
            )

    # Sub-category labels (Dyn Cold, Hot Dyn, Stat Cold, Hot Stat)
    ax.set_xticks(all_sub_positions)
    ax.set_xticklabels(all_sub_labels, fontsize=7.0, color="#444444", rotation=15)

    # Major X-axis titles centered for each language
    for lang_idx, lang in enumerate(LANG_ORDER):
        ax.text(
            group_x_indices[lang_idx],
            -0.12,
            LANG_LABELS[lang],
            transform=ax.get_xaxis_transform(),
            ha="center",
            va="top",
            fontweight="bold",
            fontsize=12,
        )

    ax.set_ylabel("Overhead Time (seconds)", fontweight="bold", fontsize=10)
    ax.set_title("Build Time Overhead Comparison: Polymorphism (Cold vs. Hot Builds)", pad=16, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    ax.set_ylim(0.0, max(global_max_y * 1.22, 0.45))

    # Reference Legend Style
    real_marker = plt.Line2D([0], [0], color="black", linewidth=2.0, label=r"$T_\mathrm{real}$ (Real Time)")
    cold_user_patch = mpatches.Patch(facecolor="#333333", edgecolor="#111111", label=r"Cold $T_\mathrm{user}$")
    cold_sys_patch = mpatches.Patch(facecolor="#666666", edgecolor="#111111", label=r"Cold $T_\mathrm{sys}$")
    hot_user_patch = mpatches.Patch(facecolor="#333333", edgecolor="#111111", hatch="//", label=r"Hot $T_\mathrm{user}$")
    hot_sys_patch = mpatches.Patch(facecolor="#666666", edgecolor="#111111", hatch="//", label=r"Hot $T_\mathrm{sys}$")

    ax.legend(
        handles=[real_marker, cold_user_patch, cold_sys_patch, hot_user_patch, hot_sys_patch],
        loc="upper left",
        ncol=3,
        framealpha=0.9,
        fontsize=8.0,
    )

    plt.tight_layout()

    out_file = OUTPUT_DIR / "overhead_poly_interleaved_by_lang.png"
    plt.savefig(out_file, dpi=300, bbox_inches="tight")
    print(f"Saved plot: {out_file}")

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

    if not CSV_PATH.is_file():
        print(f"CSV file not found at {CSV_PATH}")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)
    df_overhead = calculate_overhead_dataframe(df)

    plot_poly_interleaved_by_lang(df_overhead)

    if SHOW_PLOTS:
        print("\nPlot generation complete.")
        plt.ioff()
        plt.show()


if __name__ == "__main__":
    main()

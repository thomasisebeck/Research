from pathlib import Path
import re
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import pandas as pd

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("build_times_all.csv")
OUTPUT_DIR = Path("plots_build_time")

LANG_ORDER = ["cpp", "rust", "zig"]
LANG_LABELS = {"cpp": "C++", "rust": "Rust", "zig": "Zig"}

MAIN_SWEEP_INCS = [
    "INC_5",
    "INC_1",
    "INC_0.5",
    "INC_0.1",
    "INC_0.05",
    "INC_0.01",
]

FINE_SWEEP_INCS = [
    "INC_0.005",
    "INC_0.001",
    "INC_0.0005",
    "INC_0.0001",
]

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


def plot_tuser_paired_textured_sweep(
    df: pd.DataFrame,
    inc_list: list[str],
    include_runtime_lut: bool,
    plot_title: str,
    output_filename: str,
):
    """
    Plots T_user CPU overhead for Cold (solid) and Hot (hatched) builds.
    Calculates delta relative to build_offset T_user and propagates std dev:
        std_diff = sqrt(var_exp + var_base)
    Non-compiling / missing entries (e.g. C++ at INC_0.0001) are rendered as grey bars.
    """
    df_base = df[df["label"] == "build_offset"].set_index("lang")
    df_lut_rt = df[df["label"] == "lut_runtime"].set_index("lang")
    df_lut_ct = df[df["label"] == "lut_comptime"]

    if df_base.empty:
        print("Error: Missing 'build_offset' baseline entries.")
        return

    categories = []
    if include_runtime_lut:
        categories.append("Runtime\nLUT")
    categories.extend([inc.replace("INC_", "Δ=") for inc in inc_list])

    num_categories = len(categories)
    num_langs = len(LANG_ORDER)

    group_x_indices = np.arange(num_categories)
    total_group_width = 0.85
    lang_slot_width = total_group_width / num_langs
    bar_width = lang_slot_width * 0.44

    fig, ax = plt.subplots(figsize=(13.0 if num_categories <= 5 else 18.0, 6.5), dpi=300)

    # 1. Collect data across languages and determine global_max_y for scaling
    lang_data = []
    global_max_y = 0.0

    def collect_user_data(lang, build_state):
        base_row = df_base.loc[lang]
        df_lang_ct = df_lut_ct[df_lut_ct["lang"] == lang]

        u_vals, u_stds, compiled_flags = [], [], []

        base_u_mean = float(base_row[f"{build_state}_user_mean"])
        base_u_var = float(base_row[f"{build_state}_user_variance"])

        if include_runtime_lut:
            if lang in df_lut_rt.index and not pd.isna(df_lut_rt.loc[lang][f"{build_state}_user_mean"]):
                rt_row = df_lut_rt.loc[lang]
                u_mean = float(rt_row[f"{build_state}_user_mean"])
                u_var = float(rt_row[f"{build_state}_user_variance"])
                
                diff_mean = max(0.0, u_mean - base_u_mean)
                diff_std = np.sqrt(u_var + base_u_var)
                compiled = True
            else:
                diff_mean, diff_std = 0.0, 0.0
                compiled = False

            u_vals.append(diff_mean)
            u_stds.append(diff_std)
            compiled_flags.append(compiled)

        for inc in inc_list:
            row_match = df_lang_ct[df_lang_ct["setting"] == inc]
            if not row_match.empty and not pd.isna(row_match.iloc[0][f"{build_state}_user_mean"]):
                ct_row = row_match.iloc[0]
                u_mean = float(ct_row[f"{build_state}_user_mean"])
                u_var = float(ct_row[f"{build_state}_user_variance"])

                diff_mean = max(0.0, u_mean - base_u_mean)
                diff_std = np.sqrt(u_var + base_u_var)
                compiled = True
            else:
                diff_mean, diff_std = 0.0, 0.0
                compiled = False

            u_vals.append(diff_mean)
            u_stds.append(diff_std)
            compiled_flags.append(compiled)

        return u_vals, u_stds, compiled_flags

    for lang_idx, lang in enumerate(LANG_ORDER):
        if lang not in df_base.index:
            continue

        lang_center_x = group_x_indices - (total_group_width / 2.0) + (lang_idx + 0.5) * lang_slot_width
        x_cold = lang_center_x - (bar_width / 2.0) - 0.01
        x_hot = lang_center_x + (bar_width / 2.0) + 0.01

        c_u, c_std, c_comp = collect_user_data(lang, "cold")
        h_u, h_std, h_comp = collect_user_data(lang, "hot")

        # Track max y-value for scale
        for u, std, comp in zip(c_u + h_u, c_std + h_std, c_comp + h_comp):
            if comp:
                top_pt = u + std
                if top_pt > global_max_y:
                    global_max_y = top_pt

        lang_data.append({
            "lang": lang,
            "x_cold": x_cold,
            "x_hot": x_hot,
            "c_u": c_u, "c_std": c_std, "c_comp": c_comp,
            "h_u": h_u, "h_std": h_std, "h_comp": h_comp,
        })

    placeholder_height = max(global_max_y * 0.06, 0.5)
    has_uncompiled = False

    # 2. Render Bars and Annotations
    for data_item in lang_data:
        lang = data_item["lang"]
        x_cold, x_hot = data_item["x_cold"], data_item["x_hot"]
        c_u, c_std, c_comp = data_item["c_u"], data_item["c_std"], data_item["c_comp"]
        h_u, h_std, h_comp = data_item["h_u"], data_item["h_std"], data_item["h_comp"]

        colors = COLOR_MAPS[lang]

        for idx in range(num_categories):
            # --- 1. Cold T_user Bar ---
            x_c, val_c, std_c, comp_c = x_cold[idx], c_u[idx], c_std[idx], c_comp[idx]

            if comp_c:
                ax.bar(
                    x_c, val_c, width=bar_width,
                    color=colors["cold_user"], edgecolor="#111111", linewidth=0.6, zorder=2,
                    label=f"{LANG_LABELS[lang]} Cold $T_\\mathrm{{user}}$",
                )
                ax.errorbar(
                    x_c, val_c, yerr=std_c, fmt="none", ecolor="black",
                    capsize=1.5, capthick=0.6, zorder=5,
                )
                val_str_c = f"{val_c:.2f}s\n±{std_c:.2f}s" if val_c >= 0.01 else "0.00s"
                ax.annotate(
                    val_str_c, xy=(x_c, val_c), xytext=(0, 2),
                    textcoords="offset points", ha="center", va="bottom",
                    fontsize=5.0 if num_categories <= 5 else 4.6, fontweight="bold",
                    rotation=35 if num_categories <= 5 else 45,
                )
            else:
                has_uncompiled = True
                ax.bar(
                    x_c, placeholder_height, width=bar_width,
                    color="#555555", edgecolor="#111111", linewidth=0.6, zorder=2,
                )
                ax.annotate(
                    "Did Not\nCompile", xy=(x_c, placeholder_height), xytext=(0, 2),
                    textcoords="offset points", ha="center", va="bottom",
                    fontsize=5.0 if num_categories <= 5 else 4.6, fontweight="bold",
                    color="#333333", rotation=35 if num_categories <= 5 else 45,
                )

            # --- 2. Hot T_user Bar ---
            x_h, val_h, std_h, comp_h = x_hot[idx], h_u[idx], h_std[idx], h_comp[idx]

            if comp_h:
                ax.bar(
                    x_h, val_h, width=bar_width,
                    color=colors["hot_user"], edgecolor="#111111", hatch="//", linewidth=0.6, zorder=2,
                    label=f"{LANG_LABELS[lang]} Hot $T_\\mathrm{{user}}$",
                )
                ax.errorbar(
                    x_h, val_h, yerr=std_h, fmt="none", ecolor="black",
                    capsize=1.5, capthick=0.6, zorder=5,
                )
                val_str_h = f"{val_h:.2f}s\n±{std_h:.2f}s" if val_h >= 0.01 else "0.00s"
                ax.annotate(
                    val_str_h, xy=(x_h, val_h), xytext=(0, 2),
                    textcoords="offset points", ha="center", va="bottom",
                    fontsize=5.0 if num_categories <= 5 else 4.6, fontweight="bold",
                    rotation=35 if num_categories <= 5 else 45,
                )
            else:
                has_uncompiled = True
                ax.bar(
                    x_h, placeholder_height, width=bar_width,
                    color="#777777", edgecolor="#111111", hatch="//", linewidth=0.6, zorder=2,
                )
                ax.annotate(
                    "Did Not\nCompile", xy=(x_h, placeholder_height), xytext=(0, 2),
                    textcoords="offset points", ha="center", va="bottom",
                    fontsize=5.0 if num_categories <= 5 else 4.6, fontweight="bold",
                    color="#333333", rotation=35 if num_categories <= 5 else 45,
                )

    ax.set_xticks(group_x_indices)
    ax.set_xticklabels(categories, fontweight="bold", fontsize=9)
    ax.set_ylabel("Compiler CPU Overhead ($T_\\mathrm{user}$ in seconds)", fontweight="bold", fontsize=10)
    ax.set_title(plot_title, pad=15, fontweight="bold")
    ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
    ax.set_axisbelow(True)

    # Set bottom Y-limit strictly at 0 to guarantee clean baseline
    ax.set_ylim(0.0, max(global_max_y * 1.25, 2.0))

    # Deduplicated legend + optional "Did Not Compile" patch
    handles, labels = ax.get_legend_handles_labels()
    by_label = dict(zip(labels, handles))

    if has_uncompiled:
        grey_patch = mpatches.Patch(facecolor="#777777", edgecolor="#111111", hatch="//", label="Did Not Compile")
        by_label["Did Not Compile"] = grey_patch

    ax.legend(
        by_label.values(),
        by_label.keys(),
        loc="upper left",
        ncol=4 if has_uncompiled else 3,
        framealpha=0.9,
        fontsize=7.5,
    )

    plt.tight_layout()

    out_file = OUTPUT_DIR / f"{output_filename}.png"
    plt.savefig(out_file, dpi=300, bbox_inches="tight")
    print(f"Saved T_user sweep plot: {out_file}")
    plt.show()


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if not CSV_PATH.is_file():
        print(f"CSV file not found at {CSV_PATH}")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)

    # Main Sweep (Runtime LUT up to Δ=0.01)
    plot_tuser_paired_textured_sweep(
        df=df,
        inc_list=MAIN_SWEEP_INCS,
        include_runtime_lut=True,
        plot_title="Lookup Table (LUT) Build Overhead: Main Increment Sweep ($T_\\mathrm{user}$ CPU Time)",
        output_filename="lut_main_tuser_sweep",
    )

    # Fine Resolution Sweep (Δ=0.005 down to Δ=0.0001)
    plot_tuser_paired_textured_sweep(
        df=df,
        inc_list=FINE_SWEEP_INCS,
        include_runtime_lut=False,
        plot_title="Lookup Table (LUT) Build Overhead: Fine Resolution Scaling Sweep ($T_\\mathrm{user}$ CPU Time)",
        output_filename="lut_fine_tuser_sweep",
    )


if __name__ == "__main__":
    main()

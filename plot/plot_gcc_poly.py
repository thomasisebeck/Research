import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import numpy as np

# -------------------------------------------------------------------------
# Hardcoded Data (from image_d457ed.png)
# -------------------------------------------------------------------------
LANG_ORDER = ["cpp", "rust", "zig"]
LANG_LABELS = {"cpp": "C++", "rust": "Rust", "zig": "Zig"}

# Values: (mean, std_dev)
DATA = {
    "cpp": {
        "poly_stat": (670794.8, 144205.6),
        "poly_dyn": (665201.2, 31435.4),
    },
    "rust": {
        "poly_stat": (958829.9, 5046.4),
        "poly_dyn": (2150733.7, 54999.2),
    },
    "zig": {
        "poly_stat": (943382.0, 9800.0),
        "poly_dyn": (2612918.7, 48486.9),
    },
}

COLOR_SHADES = {
    "cpp": {
        "poly_stat": "#7CA9D4",   # Light Blue
        "poly_dyn": "#1F4E79",    # Dark Blue
    },
    "rust": {
        "poly_stat": "#F4A261",   # Light Orange
        "poly_dyn": "#D66011",    # Dark Orange
    },
    "zig": {
        "poly_stat": "#81C784",   # Light Sage Green
        "poly_dyn": "#2E7D32",    # Dark Green
    },
}

BAR_CATEGORIES = [
    ("poly_stat", "Static", ""),
    ("poly_dyn", "Dynamic", "//"),
]

# -------------------------------------------------------------------------
# Matplotlib Setup & Rendering
# -------------------------------------------------------------------------
plt.rcParams.update(
    {
        "font.family": "sans-serif",
        "font.size": 8,
        "axes.labelsize": 9,
        "axes.titlesize": 12,
        "xtick.labelsize": 11,
        "ytick.labelsize": 9,
        "figure.titlesize": 13,
        "axes.edgecolor": "#333333",
        "axes.linewidth": 0.8,
    }
)

fig, ax = plt.subplots(figsize=(8.0, 4.8), dpi=300)

num_languages = len(LANG_ORDER)
num_bars_per_lang = len(BAR_CATEGORIES)

x_indices = np.arange(num_languages)
total_group_width = 0.55
bar_width = total_group_width / num_bars_per_lang

all_heights = []

for idx, (label_key, cat_display_name, hatch) in enumerate(BAR_CATEGORIES):
    offset = x_indices - (total_group_width / 2) + (idx + 0.5) * bar_width
    means, stds, colors = [], [], []

    for lang in LANG_ORDER:
        m, s = DATA[lang][label_key]
        means.append(m)
        stds.append(s)
        colors.append(COLOR_SHADES[lang][label_key])
        all_heights.append(m + s)

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
ax.set_xticklabels([LANG_LABELS[l] for l in LANG_ORDER], fontweight="bold", fontsize=12)
ax.set_title("Runtime (ns)", pad=12, fontweight="bold")
ax.yaxis.grid(True, linestyle="--", alpha=0.5, zorder=0)
ax.set_axisbelow(True)

if all_heights:
    ax.set_ylim(0, max(all_heights) * 1.30)

dispatch_legend_elements = [
    Patch(facecolor="#999999", edgecolor="#333333", hatch="", label="Static"),
    Patch(facecolor="#333333", edgecolor="#333333", hatch="//", label="Dynamic"),
]

ax.legend(
    handles=dispatch_legend_elements,
    title="Dispatch Mode",
    loc="upper left",
    frameon=True,
    fontsize=8.5,
)

plt.tight_layout()
plt.savefig("plots/combined_dipatch_runtime_ns_gcc.png", dpi=300, bbox_inches="tight")
plt.show()

from pathlib import Path
import re
import numpy as np
import pandas as pd
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")
OUTPUT_TEX = Path("generated_branching_tables.tex")

# Defines all 7 metrics: (CSV column prefix, LaTeX Display Name)
METRICS = [
    ("runtime_ns", "Runtime (ns)"),
    ("cycles", "Cycles"),
    ("instructions", "Instructions"),
    ("cache-misses", "Cache Misses"),
    ("cache-references", "Cache References"),
    ("branches", "Branches"),
    ("branch-misses", "Branch Misses"),
]

SETTING_MAP = {
    "LOW_false_false_false": "LOW",
    "MED_true_false_true": "MED",
    "HIGH_true_true_true": "HIGH",
}

SETTING_ORDER = ["LOW", "MED", "HIGH"]
SAMPLE_SIZE_N = 30  # Standard sample size per benchmark run

# -------------------------------------------------------------------------
# Formatting & Statistics Helpers
# -------------------------------------------------------------------------

def format_latex_num(val: float) -> str:
    """Formats numbers with LaTeX thin spaces as thousands separators."""
    if pd.isna(val):
        return "N/A"
    if val >= 1000:
        return f"{val:,.2f}".replace(",", r"\,")
    return f"{val:.2f}"

def compute_pct_and_pvalue(mean_a: float, std_a: float, n_a: int,
                           mean_b: float, std_b: float, n_b: int):
    """
    Calculates percentage difference (A vs B) and Welch's t-test p-value.
    Percentage diff = ((mean_a - mean_b) / mean_b) * 100
    """
    if mean_b == 0 or pd.isna(mean_a) or pd.isna(mean_b):
        return 0.0, 1.0

    pct_diff = ((mean_a - mean_b) / mean_b) * 100.0

    if std_a == 0 and std_b == 0:
        return pct_diff, 1.0

    se_a = (std_a ** 2) / max(n_a, 1)
    se_b = (std_b ** 2) / max(n_b, 1)
    se_diff = np.sqrt(se_a + se_b)

    if se_diff == 0:
        p_val = 1.0
    else:
        t_stat = (mean_a - mean_b) / se_diff
        df_num = (se_a + se_b) ** 2
        df_denom = (se_a ** 2) / max(n_a - 1, 1) + (se_b ** 2) / max(n_b - 1, 1)
        df = df_num / df_denom if df_denom > 0 else (n_a + n_b - 2)
        p_val = stats.t.sf(np.abs(t_stat), df) * 2

    return pct_diff, p_val

def format_diff_cell(pct_diff: float, p_val: float) -> str:
    """Formats percentage change and p-value with bolding if statistically significant (p < 0.05)."""
    sign = "+" if pct_diff > 0 else ""
    p_str = "$p < 0.001$" if p_val < 0.001 else f"$p = {p_val:.3f}$"
    val_str = f"{sign}{pct_diff:.2f}\\%"
    
    if p_val < 0.05:
        return f"\\textbf{{{val_str}}} ({p_str})"
    return f"{val_str} ({p_str})"

# -------------------------------------------------------------------------
# Table Generator
# -------------------------------------------------------------------------

def generate_full_branching_table(df: pd.DataFrame, label: str, raw_setting: str, friendly_setting: str) -> str:
    """
    Generates a unified LaTeX table containing both raw values (mean +/- std)
    and pairwise statistical comparisons for all 7 metrics.
    """
    sub_df = df[(df["label"] == label) & (df["setting"] == raw_setting)]
    
    label_type = "Compile-Time Tagged Union" if "comptime" in label else "Runtime Dynamic Dispatch"
    tex_label = f"tab:image_pipeline_{friendly_setting.lower()}_{'cmp' if 'comptime' in label else 'run'}"
    
    latex = []
    latex.append(f"% ==================== Image Pipeline ({friendly_setting} - {label_type}) ====================")
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\footnotesize")
    latex.append(r"\setlength{\tabcolsep}{2.5pt}")
    latex.append(f"\\caption{{Image Pipeline Branching Performance ({label_type}) --- \\textbf{{{friendly_setting}}} Workload Setting}}")
    latex.append(f"\\label{{{tex_label}}}")
    latex.append(r"\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l c c c @{}}")
    latex.append(r"\toprule")
    latex.append(r"\textbf{Metric} & \multicolumn{2}{c}{\textbf{C++}} & \multicolumn{2}{c}{\textbf{Rust}} & \multicolumn{2}{c}{\textbf{Zig}} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\")
    latex.append(r"\midrule")

    for metric_prefix, metric_name in METRICS:
        def get_stats(lang_name):
            row = sub_df[sub_df["lang"] == lang_name]
            if row.empty:
                return None, None
            m = row[f"{metric_prefix}_mean"].values[0]
            s = row[f"{metric_prefix}_std_dev"].values[0]
            return float(m), float(s)

        cpp_m, cpp_s = get_stats("cpp")
        rust_m, rust_s = get_stats("rust")
        zig_m, zig_s = get_stats("zig")

        # Format Raw Strings
        cpp_str = f"{format_latex_num(cpp_m)} & {format_latex_num(cpp_s)}" if cpp_m is not None else "N/A & N/A"
        rust_str = f"{format_latex_num(rust_m)} & {format_latex_num(rust_s)}" if rust_m is not None else "N/A & N/A"
        zig_str = f"{format_latex_num(zig_m)} & {format_latex_num(zig_s)}" if zig_m is not None else "N/A & N/A"

        # Pairwise Comparisons
        r_c_cell = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, SAMPLE_SIZE_N, cpp_m, cpp_s, SAMPLE_SIZE_N)) if (rust_m and cpp_m) else "N/A"
        z_c_cell = format_diff_cell(*compute_pct_and_pvalue(zig_m, zig_s, SAMPLE_SIZE_N, cpp_m, cpp_s, SAMPLE_SIZE_N)) if (zig_m and cpp_m) else "N/A"
        r_z_cell = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, SAMPLE_SIZE_N, zig_m, zig_s, SAMPLE_SIZE_N)) if (rust_m and zig_m) else "N/A"

        latex.append(f"{metric_name} & {cpp_str} & {rust_str} & {zig_str} & {r_c_cell} & {z_c_cell} & {r_z_cell} \\\\")

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular*}")
    latex.append(r"\end{table}")
    latex.append("\n")

    return "\n".join(latex)

# -------------------------------------------------------------------------
# Main Execution
# -------------------------------------------------------------------------

def main():
    if not CSV_PATH.is_file():
        print(f"Error: CSV file not found at {CSV_PATH}.")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)
    output_tables = []

    labels = ["image_pipeline_comptime", "image_pipeline_runtime"]

    for label in labels:
        for raw_setting, friendly_setting in SETTING_MAP.items():
            # Verify data exists for this combination
            if not df[(df["label"] == label) & (df["setting"] == raw_setting)].empty:
                output_tables.append(
                    generate_full_branching_table(df, label, raw_setting, friendly_setting)
                )

    full_tex_content = "\n".join(output_tables)

    with open(OUTPUT_TEX, "w", encoding="utf-8") as f:
        f.write(full_tex_content)

    print(f"Successfully generated all LaTeX branching tables to: {OUTPUT_TEX}")

if __name__ == "__main__":
    main()

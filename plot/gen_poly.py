import numpy as np
import pandas as pd
from pathlib import Path
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")
OUTPUT_TEX = Path("generated_tables.tex")

METRICS = [
    ("runtime_ns", "Runtime (ns)"),
    ("cycles", "Cycles"),
    ("instructions", "Instructions"),
    ("cache-misses", "Cache Misses"),
    ("cache-references", "Cache References"),
    ("branches", "Branches"),
    ("branch-misses", "Branch Misses"),
]

# -------------------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------------------

def format_latex_num(val: float) -> str:
    """Formats numbers with LaTeX thin spaces as thousands separators."""
    if pd.isna(val):
        return "N/A"
    return f"{val:,.2f}".replace(",", r"\,")

def compute_pct_and_pvalue(mean_a: float, std_a: float, n_a: int,
                           mean_b: float, std_b: float, n_b: int):
    """
    Calculates percentage difference (A vs B) and Welch's t-test p-value.
    Percentage diff = ((mean_a - mean_b) / mean_b) * 100
    """
    if mean_b == 0 or pd.isna(mean_a) or pd.isna(mean_b):
        return 0.0, 1.0

    pct_diff = ((mean_a - mean_b) / mean_b) * 100.0

    # Welch's t-test from summary stats
    se_a = (std_a ** 2) / n_a
    se_b = (std_b ** 2) / n_b
    se_diff = np.sqrt(se_a + se_b)

    if se_diff == 0:
        p_val = 1.0
    else:
        t_stat = (mean_a - mean_b) / se_diff
        # Welch–Satterthwaite degrees of freedom
        df_num = (se_a + se_b) ** 2
        df_denom = (se_a ** 2) / (n_a - 1) + (se_b ** 2) / (n_b - 1)
        df = df_num / df_denom if df_denom > 0 else (n_a + n_b - 2)
        p_val = stats.t.sf(np.abs(t_stat), df) * 2

    return pct_diff, p_val

def format_diff_cell(pct_diff: float, p_val: float) -> str:
    """Formats percentage change and p-value with bolding if p < 0.05."""
    sign = "+" if pct_diff > 0 else ""
    p_str = "$p < 0.001$" if p_val < 0.001 else f"$p = {p_val:.3f}$"
    val_str = f"{sign}{pct_diff:.2f}\\%"
    
    if p_val < 0.05:
        return f"\\textbf{{{val_str}}} ({p_str})"
    else:
        return f"{val_str} ({p_str})"

# -------------------------------------------------------------------------
# Table Generators
# -------------------------------------------------------------------------

def generate_stat_diff_table(df: pd.DataFrame, label: str, setting: str | None, title: str, tex_label: str) -> str:
    """
    Generates 4-column statistical significance comparison LaTeX tables.
    If setting is None, filters by label only (ignoring the setting column).
    """
    if setting is None:
        sub_df = df[df["label"] == label]
    else:
        sub_df = df[(df["label"] == label) & (df["setting"] == setting)]
    
    latex = []
    latex.append(f"% ==================== {title} ====================")
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(f"\\caption{{{title} --- Statistical Significance and Percentage Differences ($H_1: \\text{{Lang}}_A \\neq \\text{{Lang}}_B$)}}")
    latex.append(f"\\label{{{tex_label}}}")
    latex.append(r"\begin{tabular}{l ccc}")
    latex.append(r"\toprule")
    latex.append(r"\textbf{Metric} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\")
    latex.append(r"\midrule")

    for metric_key, metric_name in METRICS:
        n_obs = 30
        
        def get_stats(lang):
            row = sub_df[sub_df["lang"] == lang]
            if row.empty:
                return 0.0, 0.0, n_obs
            m = row[f"{metric_key}_mean"].values[0]
            s = row[f"{metric_key}_std_dev"].values[0]
            return float(m), float(s), n_obs

        cpp_m, cpp_s, cpp_n = get_stats("cpp")
        rust_m, rust_s, rust_n = get_stats("rust")
        zig_m, zig_s, zig_n = get_stats("zig")

        rust_cpp_pct, rust_cpp_p = compute_pct_and_pvalue(rust_m, rust_s, rust_n, cpp_m, cpp_s, cpp_n)
        zig_cpp_pct, zig_cpp_p = compute_pct_and_pvalue(zig_m, zig_s, zig_n, cpp_m, cpp_s, cpp_n)
        rust_zig_pct, rust_zig_p = compute_pct_and_pvalue(rust_m, rust_s, rust_n, zig_m, zig_s, zig_n)

        cell_rust_cpp = format_diff_cell(rust_cpp_pct, rust_cpp_p)
        cell_zig_cpp = format_diff_cell(zig_cpp_pct, zig_cpp_p)
        cell_rust_zig = format_diff_cell(rust_zig_pct, rust_zig_p)

        latex.append(f"{metric_name} & {cell_rust_cpp} & {cell_zig_cpp} & {cell_rust_zig} \\\\")

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular}")
    latex.append(r"\end{table}")
    latex.append("\n")
    
    return "\n".join(latex)

def generate_workload_detail_table(df: pd.DataFrame, setting: str, setting_name: str, rel_cost: str) -> str:
    """Generates detailed 8-column breakdown tables (Runtime, Instructions, Branch Misses)."""
    sub_df = df[df["setting"] == setting]
    
    latex = []
    latex.append(f"% -----------------------------------------------------------------")
    latex.append(f"% {setting_name.upper()} SETTING TABLE")
    latex.append(f"% -----------------------------------------------------------------")
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\footnotesize")
    latex.append(r"\setlength{\tabcolsep}{1.5pt}")
    latex.append(f"\\caption{{Image Pipeline (Branching) Performance for \\textbf{{{setting_name.upper()}}} Workload Setting (Relative Branching Cost: \\textbf{{{rel_cost}}})}}")
    latex.append(f"\\label{{tab:image_pipeline_{setting_name.lower()}}}")
    latex.append(r"\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}} l l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l @{}}")
    latex.append(r"\toprule")
    latex.append(r"\textbf{Language} & \textbf{Type} & \multicolumn{2}{c}{\textbf{\shortstack{Runtime\\(ns)}}} & \multicolumn{2}{c}{\textbf{Instructions}} & \multicolumn{2}{c}{\textbf{\shortstack{Branch\\Misses}}} \\")
    latex.append(r"\midrule")

    langs = [("cpp", "C++"), ("rust", "Rust"), ("zig", "Zig")]
    types = [("image_pipeline_runtime", "run"), ("image_pipeline_comptime", "cmp")]

    for i, (lang_code, lang_disp) in enumerate(langs):
        for j, (label_code, type_disp) in enumerate(types):
            row = sub_df[(sub_df["lang"] == lang_code) & (sub_df["label"] == label_code)]
            
            if not row.empty:
                rt_m = format_latex_num(row["runtime_ns_mean"].values[0])
                rt_s = format_latex_num(row["runtime_ns_std_dev"].values[0])
                ins_m = format_latex_num(row["instructions_mean"].values[0])
                ins_s = format_latex_num(row["instructions_std_dev"].values[0])
                bm_m = format_latex_num(row["branch-misses_mean"].values[0])
                bm_s = format_latex_num(row["branch-misses_std_dev"].values[0])
            else:
                rt_m = rt_s = ins_m = ins_s = bm_m = bm_s = "0.00"

            lang_cell = f"\\multirow{{2}}{{*}}{{{lang_disp}}}" if j == 0 else ""
            latex.append(f"{lang_cell:22s} & {type_disp} & {rt_m} & {rt_s} & {ins_m} & {ins_s} & {bm_m} & {bm_s} \\\\")

        if i < len(langs) - 1:
            latex.append(r"\cmidrule{1-8}")

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
        print(f"CSV file not found at {CSV_PATH}.")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)
    output_tables = []

    # 1. Calibration (Ignores setting)
    output_tables.append(generate_stat_diff_table(
        df, "calibration", None, "Calibration Phase", "tab:calibration_N/A"
    ))

    # 2. Polymorphism (Static and Dynamic - Both Ignore setting)
    output_tables.append(generate_stat_diff_table(
        df, "poly_stat", None, "Polymorphism (Static)", "tab:poly_stat_N/A"
    ))
    output_tables.append(generate_stat_diff_table(
        df, "poly_dyn", None, "Polymorphism (Dynamic)", "tab:poly_dyn_N/A"
    ))

    # 3. Image Pipeline Statistical Significance Tables
    stat_configs = [
        ("image_pipeline_comptime", "LOW_false_false_false", "Compile-Time Image Pipeline (LOW)", "tab:image_pipeline_comptime_LOW_false_false_false"),
        ("image_pipeline_comptime", "MED_true_false_true", "Compile-Time Image Pipeline (MED)", "tab:image_pipeline_comptime_MED_true_false_true"),
        ("image_pipeline_comptime", "HIGH_true_true_true", "Compile-Time Image Pipeline (HIGH)", "tab:image_pipeline_comptime_HIGH_true_true_true"),
        ("image_pipeline_runtime", "LOW_false_false_false", "Runtime Image Pipeline (LOW)", "tab:image_pipeline_runtime_LOW_false_false_false"),
        ("image_pipeline_runtime", "MED_true_false_true", "Runtime Image Pipeline (MED)", "tab:image_pipeline_runtime_MED_true_false_true"),
        ("image_pipeline_runtime", "HIGH_true_true_true", "Runtime Image Pipeline (HIGH)", "tab:image_pipeline_runtime_HIGH_true_true_true"),
    ]

    for label, setting, title, tex_label in stat_configs:
        output_tables.append(generate_stat_diff_table(df, label, setting, title, tex_label))

    # 4. Workload Detail Tables (LOW, MED, HIGH)
    workload_configs = [
        ("LOW_false_false_false", "LOW", "High"),
        ("MED_true_false_true", "MED", "Medium"),
        ("HIGH_true_true_true", "HIGH", "Low"),
    ]

    for setting, name, cost in workload_configs:
        output_tables.append(generate_workload_detail_table(df, setting, name, cost))

    full_tex_content = "\n".join(output_tables)

    with open(OUTPUT_TEX, "w", encoding="utf-8") as f:
        f.write(full_tex_content)

    print(f"Successfully generated all LaTeX tables to: {OUTPUT_TEX}")

if __name__ == "__main__":
    main()

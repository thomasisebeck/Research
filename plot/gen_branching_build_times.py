from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("build_times_all.csv")
OUTPUT_TEX = Path("generated_branching_build_tables.tex")

# Build metrics matching the CSV column headers
BUILD_METRICS = [
    ("cold_real", "Cold Real ($T_\\mathrm{real}$)"),
    ("cold_user", "Cold User ($T_\\mathrm{user}$)"),
    ("cold_sys", "Cold Sys ($T_\\mathrm{sys}$)"),
    ("hot_real", "Hot Real ($T_\\mathrm{real}$)"),
    ("hot_user", "Hot User ($T_\\mathrm{user}$)"),
    ("hot_sys", "Hot Sys ($T_\\mathrm{sys}$)"),
]

SETTING_MAP = [
    ("LOW_false_false_false", "LOW"),
    ("MED_true_false_true", "MED"),
    ("HIGH_true_true_true", "HIGH"),
]

SAMPLE_SIZE_N = 15  # Benchmark runs per build configuration

# -------------------------------------------------------------------------
# Formatting & Statistics Helpers
# -------------------------------------------------------------------------

def format_latex_num(val: float) -> str:
    """Formats numbers with LaTeX thin spaces as thousands separators."""
    if pd.isna(val) or val is None:
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
        if mean_a == mean_b:
            return pct_diff, 1.0
        # Sub-millisecond variance floor for distinct non-zero means
        std_a, std_b = 1e-6, 1e-6

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
    """Formats percentage change and p-value concisely for tight table columns."""
    sign = "+" if pct_diff > 0 else ""
    p_str = "$p<.001$" if p_val < 0.001 else f"$p={p_val:.3f}$"
    val_str = f"{sign}{pct_diff:.2f}\\%"
    
    if p_val < 0.05:
        return f"\\textbf{{{val_str}}} ({p_str})"
    return f"{val_str} ({p_str})"

# -------------------------------------------------------------------------
# Table 1: Language Build Comparison Across Workload Settings (Resized)
# -------------------------------------------------------------------------

def generate_language_build_comparison_table(df: pd.DataFrame) -> str:
    latex = []
    latex.append(r"% ==================== TABLE 1: LANGUAGE BUILD COMPARISON ====================")
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\caption{Image Pipeline Branching Build Performance --- Inter-Language Comparison Across Workload Settings}")
    latex.append(r"\label{tab:branching_build_language_comparison}")
    latex.append(r"\resizebox{\textwidth}{!}{%")
    latex.append(r"\setlength{\tabcolsep}{1.0pt}")
    latex.append(r"\begin{tabular}{l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l c c c}")
    latex.append(r"\toprule")
    latex.append(r"\textbf{Metric} & \multicolumn{2}{c}{\textbf{C++ (s)}} & \multicolumn{2}{c}{\textbf{Rust (s)}} & \multicolumn{2}{c}{\textbf{Zig (s)}} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\")

    branch_types = [
        ("image_pipeline_comptime", "Compile-Time Branching"),
        ("image_pipeline_runtime", "Runtime Branching"),
    ]

    for raw_setting, friendly_setting in SETTING_MAP:
        latex.append(r"\midrule")
        latex.append(f"\\multicolumn{{10}}{{@{{}}l}}{{\\textbf{{\\normalsize Workload Setting: {friendly_setting}}}}} \\\\")
        
        for label_key, label_title in branch_types:
            sub_df = df[(df["label"] == label_key) & (df["setting"] == raw_setting)]
            latex.append(r"\midrule")
            latex.append(f"\\multicolumn{{10}}{{@{{}}l}}{{\\textbf{{\\small \\textit{{{label_title}}}}}}} \\\\")
            latex.append(r"\midrule")

            for metric_prefix, metric_name in BUILD_METRICS:
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

                cpp_str = f"{format_latex_num(cpp_m)} & {format_latex_num(cpp_s)}" if cpp_m is not None else "N/A & N/A"
                rust_str = f"{format_latex_num(rust_m)} & {format_latex_num(rust_s)}" if rust_m is not None else "N/A & N/A"
                zig_str = f"{format_latex_num(zig_m)} & {format_latex_num(zig_s)}" if zig_m is not None else "N/A & N/A"

                r_c_cell = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, SAMPLE_SIZE_N, cpp_m, cpp_s, SAMPLE_SIZE_N)) if (rust_m is not None and cpp_m is not None) else "N/A"
                z_c_cell = format_diff_cell(*compute_pct_and_pvalue(zig_m, zig_s, SAMPLE_SIZE_N, cpp_m, cpp_s, SAMPLE_SIZE_N)) if (zig_m is not None and cpp_m is not None) else "N/A"
                r_z_cell = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, SAMPLE_SIZE_N, zig_m, zig_s, SAMPLE_SIZE_N)) if (rust_m is not None and zig_m is not None) else "N/A"

                latex.append(f"{metric_name} & {cpp_str} & {rust_str} & {zig_str} & {r_c_cell} & {z_c_cell} & {r_z_cell} \\\\")

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular}")
    latex.append(r"}")
    latex.append(r"\end{table}")
    latex.append("\n")

    return "\n".join(latex)

# -------------------------------------------------------------------------
# Table 2: Intra-Language Build Time Gain (Compile-Time vs Runtime)
# -------------------------------------------------------------------------

def generate_intralanguage_build_speedup_table(df: pd.DataFrame) -> str:
    latex = []
    latex.append(r"% ==================== TABLE 2: INTRA-LANGUAGE BUILD SPEEDUP ====================")
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(r"\caption{Image Pipeline Branching Build Performance --- Intra-Language Build Time Gain (\textbf{Compile-Time vs. Runtime Branching})}")
    latex.append(r"\label{tab:branching_build_intralanguage_speedup}")
    latex.append(r"\resizebox{\textwidth}{!}{%")
    latex.append(r"\setlength{\tabcolsep}{3.0pt}")
    latex.append(r"\begin{tabular}{l c c c}")
    latex.append(r"\toprule")
    latex.append(r"\textbf{Metric} & \textbf{C++ (Comptime vs. Runtime)} & \textbf{Rust (Comptime vs. Runtime)} & \textbf{Zig (Comptime vs. Runtime)} \\")

    for raw_setting, friendly_setting in SETTING_MAP:
        latex.append(r"\midrule")
        latex.append(f"\\multicolumn{{4}}{{@{{}}l}}{{\\textbf{{\\normalsize Workload Setting: {friendly_setting}}}}} \\\\")
        latex.append(r"\midrule")

        df_cmp = df[(df["label"] == "image_pipeline_comptime") & (df["setting"] == raw_setting)]
        df_run = df[(df["label"] == "image_pipeline_runtime") & (df["setting"] == raw_setting)]

        for metric_prefix, metric_name in BUILD_METRICS:
            cells = []
            for lang in ["cpp", "rust", "zig"]:
                row_cmp = df_cmp[df_cmp["lang"] == lang]
                row_run = df_run[df_run["lang"] == lang]

                if not row_cmp.empty and not row_run.empty:
                    m_cmp = float(row_cmp[f"{metric_prefix}_mean"].values[0])
                    s_cmp = float(row_cmp[f"{metric_prefix}_std_dev"].values[0])
                    m_run = float(row_run[f"{metric_prefix}_mean"].values[0])
                    s_run = float(row_run[f"{metric_prefix}_std_dev"].values[0])

                    pct_diff, p_val = compute_pct_and_pvalue(m_cmp, s_cmp, SAMPLE_SIZE_N, m_run, s_run, SAMPLE_SIZE_N)
                    cells.append(format_diff_cell(pct_diff, p_val))
                else:
                    cells.append("N/A")

            latex.append(f"{metric_name} & {cells[0]} & {cells[1]} & {cells[2]} \\\\")

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular}")
    latex.append(r"}")
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

    tex_table1 = generate_language_build_comparison_table(df)
    tex_table2 = generate_intralanguage_build_speedup_table(df)

    full_tex_content = f"{tex_table1}\n\n{tex_table2}"

    with open(OUTPUT_TEX, "w", encoding="utf-8") as f:
        f.write(full_tex_content)

    print(f"Successfully generated 2 consolidated LaTeX branching build tables to: {OUTPUT_TEX}")

if __name__ == "__main__":
    main()

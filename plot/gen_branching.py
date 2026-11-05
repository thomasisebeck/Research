from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

RUNTIME_CSV_PATH = Path("runtime_times_all.csv")
BUILD_CSV_PATH = Path("build_times_all.csv")

OUTPUT_RUNTIME_TEX = Path("generated_branching_runtime_tables.tex")
OUTPUT_BUILD_TEX = Path("generated_branching_build_tables.tex")

RUNTIME_METRICS = [
    ("runtime_ns", "Runtime (ns)"),
    ("cycles", "Cycles"),
    ("instructions", "Instructions"),
    ("cache-misses", "Cache Misses"),
    ("cache-references", "Cache References"),
    ("branches", "Branches"),
    ("branch-misses", "Branch Misses"),
]

BUILD_METRICS = [
    ("cold_real", r"Cold Real ($T_\mathrm{real}$)"),
    ("cold_user", r"Cold User ($T_\mathrm{user}$)"),
    ("cold_sys", r"Cold Sys ($T_\mathrm{sys}$)"),
    ("hot_real", r"Hot Real ($T_\mathrm{real}$)"),
    ("hot_user", r"Hot User ($T_\mathrm{user}$)"),
    ("hot_sys", r"Hot Sys ($T_\mathrm{sys}$)"),
]

SETTING_MAP = [
    ("LOW_false_false_false", "low"),
    ("MED_true_false_true", "medium"),
    ("HIGH_true_true_true", "high"),
]

RUNTIME_SETTING_MAP = {
    "LOW_false_false_false": "LOW",
    "MED_true_false_true": "MED",
    "HIGH_true_true_true": "HIGH",
}

RUNTIME_SAMPLE_SIZE = 30
BUILD_SAMPLE_SIZE = 15

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
    """Calculates percentage difference (A vs B) and Welch's t-test p-value."""
    if mean_b == 0 or pd.isna(mean_a) or pd.isna(mean_b):
        return 0.0, 1.0

    pct_diff = ((mean_a - mean_b) / mean_b) * 100.0

    if std_a == 0 and std_b == 0:
        if mean_a == mean_b:
            return pct_diff, 1.0
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
    """Formats percentage change and p-value with bolding if statistically significant."""
    sign = "+" if pct_diff > 0 else ""
    p_str = "$p<.001$" if p_val < 0.001 else f"$p={p_val:.3f}$"
    val_str = f"{sign}{pct_diff:.2f}\\%"
    
    if p_val < 0.05:
        return f"\\textbf{{{val_str}}} ({p_str})"
    return f"{val_str} ({p_str})"

# -------------------------------------------------------------------------
# Function 1: Decoupled Runtime Tables Generator (Raw + Pairwise Split)
# -------------------------------------------------------------------------

def generate_all_runtime_tables(csv_path: Path) -> str:
    """Extracts, processes, and generates decoupled LaTeX runtime raw stats and pairwise tables."""
    if not csv_path.is_file():
        raise FileNotFoundError(f"Runtime CSV not found at {csv_path}")

    df = pd.read_csv(csv_path, na_filter=False)
    output_tables = []
    labels = ["image_pipeline_comptime", "image_pipeline_runtime"]

    # 1. Raw Stats Tables
    for label in labels:
        for raw_setting, friendly_setting in RUNTIME_SETTING_MAP.items():
            sub_df = df[(df["label"] == label) & (df["setting"] == raw_setting)]
            if sub_df.empty:
                continue

            label_type = "Compile-Time Branching" if "comptime" in label else "Runtime Branching"
            tex_label = f"tab:image_pipeline_{friendly_setting.lower()}_{'cmp' if 'comptime' in label else 'run'}_raw"

            latex = [
                f"% ==================== RUNTIME RAW STATS: {label_type} ({friendly_setting}) ====================",
                r"\begin{table}[htbp]",
                r"\centering",
                f"\\caption{{Image Pipeline Branching Performance --- Raw Metrics ({label_type}, \\textbf{{{friendly_setting}}} Workload Setting)}}",
                f"\\label{{{tex_label}}}",
                r"\vspace{2pt}",
                r"\centerline{%",
                r"\small",
                r"\setlength{\tabcolsep}{6.0pt}",
                r"\begin{tabular}{l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l}",
                r"\toprule",
                r"\textbf{Metric} & \multicolumn{2}{c}{\textbf{C++}} & \multicolumn{2}{c}{\textbf{Rust}} & \multicolumn{2}{c}{\textbf{Zig}} \\",
                r"\midrule"
            ]

            for metric_prefix, metric_name in RUNTIME_METRICS:
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

                latex.append(f"{metric_name} & {cpp_str} & {rust_str} & {zig_str} \\\\")

            latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
            output_tables.append("\n".join(latex))

    # 2. Pairwise Comparison Tables
    for label in labels:
        for raw_setting, friendly_setting in RUNTIME_SETTING_MAP.items():
            sub_df = df[(df["label"] == label) & (df["setting"] == raw_setting)]
            if sub_df.empty:
                continue

            label_type = "Compile-Time Branching" if "comptime" in label else "Runtime Branching"
            tex_label = f"tab:image_pipeline_{friendly_setting.lower()}_{'cmp' if 'comptime' in label else 'run'}_pairwise"

            latex = [
                f"% ==================== RUNTIME PAIRWISE: {label_type} ({friendly_setting}) ====================",
                r"\begin{table}[htbp]",
                r"\centering",
                f"\\caption{{Image Pipeline Branching Performance --- Pairwise Comparisons ({label_type}, \\textbf{{{friendly_setting}}} Workload Setting)}}",
                f"\\label{{{tex_label}}}",
                r"\vspace{2pt}",
                r"\centerline{%",
                r"\small",
                r"\setlength{\tabcolsep}{6.0pt}",
                r"\begin{tabular}{l c c c}",
                r"\toprule",
                r"\textbf{Metric} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\",
                r"\midrule"
            ]

            for metric_prefix, metric_name in RUNTIME_METRICS:
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

                r_c = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, RUNTIME_SAMPLE_SIZE, cpp_m, cpp_s, RUNTIME_SAMPLE_SIZE)) if (rust_m is not None and cpp_m is not None) else "N/A"
                z_c = format_diff_cell(*compute_pct_and_pvalue(zig_m, zig_s, RUNTIME_SAMPLE_SIZE, cpp_m, cpp_s, RUNTIME_SAMPLE_SIZE)) if (zig_m is not None and cpp_m is not None) else "N/A"
                r_z = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, RUNTIME_SAMPLE_SIZE, zig_m, zig_s, RUNTIME_SAMPLE_SIZE)) if (rust_m is not None and zig_m is not None) else "N/A"

                latex.append(f"{metric_name} & {r_c} & {z_c} & {r_z} \\\\")

            latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
            output_tables.append("\n".join(latex))

    return "\n".join(output_tables)

# -------------------------------------------------------------------------
# Function 2: Extract Build Tables Generator
# -------------------------------------------------------------------------

def generate_all_build_tables(csv_path: Path) -> str:
    """Extracts, processes, and generates all LaTeX build time metric tables."""
    if not csv_path.is_file():
        raise FileNotFoundError(f"Build CSV not found at {csv_path}")

    df = pd.read_csv(csv_path, na_filter=False)
    output_tables = []
    branch_types = [
        ("image_pipeline_comptime", "Compile-Time Branching"),
        ("image_pipeline_runtime", "Runtime Branching"),
    ]

    # Helper: Raw stats
    def raw_stats_table(raw_setting: str, friendly_setting: str) -> str:
        latex = [
            f"% ==================== RAW STATS TABLE: {friendly_setting.upper()} ====================",
            r"\begin{table}[htbp]",
            r"\centering",
            f"\\caption{{Image Pipeline Branching Build Performance --- Raw Metrics (Workload Setting: \\textbf{{{friendly_setting}}})}}",
            f"\\label{{tab:branching_build_raw_stats_{friendly_setting}}}",
            r"\vspace{2pt}",
            r"\centerline{%",
            r"\small",
            r"\setlength{\tabcolsep}{6.0pt}",
            r"\begin{tabular}{l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l}",
            r"\toprule",
            r"\textbf{Metric} & \multicolumn{2}{c}{\textbf{C++ (s)}} & \multicolumn{2}{c}{\textbf{Rust (s)}} & \multicolumn{2}{c}{\textbf{Zig (s)}} \\"
        ]

        for label_key, label_title in branch_types:
            sub_df = df[(df["label"] == label_key) & (df["setting"] == raw_setting)]
            latex.extend([r"\midrule", f"\\multicolumn{{7}}{{@{{}}l}}{{\\textbf{{\\small \\textit{{{label_title}}}}}}} \\\\", r"\midrule"])

            for metric_prefix, metric_name in BUILD_METRICS:
                def get_stats(lang_name):
                    row = sub_df[sub_df["lang"] == lang_name]
                    if row.empty:
                        return None, None
                    return float(row[f"{metric_prefix}_mean"].values[0]), float(row[f"{metric_prefix}_std_dev"].values[0])

                cpp_m, cpp_s = get_stats("cpp")
                rust_m, rust_s = get_stats("rust")
                zig_m, zig_s = get_stats("zig")

                cpp_str = f"{format_latex_num(cpp_m)} & {format_latex_num(cpp_s)}" if cpp_m is not None else "N/A & N/A"
                rust_str = f"{format_latex_num(rust_m)} & {format_latex_num(rust_s)}" if rust_m is not None else "N/A & N/A"
                zig_str = f"{format_latex_num(zig_m)} & {format_latex_num(zig_s)}" if zig_m is not None else "N/A & N/A"

                latex.append(f"{metric_name} & {cpp_str} & {rust_str} & {zig_str} \\\\")

        latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
        return "\n".join(latex)

    # Helper: Pairwise language comparisons with unique label names
    def pairwise_table(raw_setting: str, friendly_setting: str) -> str:
        latex = [
            f"% ==================== PAIRWISE TABLE: {friendly_setting.upper()} ====================",
            r"\begin{table}[htbp]",
            r"\centering",
            f"\\caption{{Image Pipeline Branching Build Performance --- Pairwise Language Comparisons (Workload Setting: \\textbf{{{friendly_setting}}})}}",
            f"\\label{{tab:branching_build_pairwise_{friendly_setting}}}",
            r"\vspace{2pt}",
            r"\centerline{%",
            r"\small",
            r"\setlength{\tabcolsep}{6.0pt}",
            r"\begin{tabular}{l c c c}",
            r"\toprule",
            r"\textbf{Metric} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\"
        ]

        for label_key, label_title in branch_types:
            sub_df = df[(df["label"] == label_key) & (df["setting"] == raw_setting)]
            latex.extend([r"\midrule", f"\\multicolumn{{4}}{{@{{}}l}}{{\\textbf{{\\small \\textit{{{label_title}}}}}}} \\\\", r"\midrule"])

            for metric_prefix, metric_name in BUILD_METRICS:
                def get_stats(lang_name):
                    row = sub_df[sub_df["lang"] == lang_name]
                    if row.empty:
                        return None, None
                    return float(row[f"{metric_prefix}_mean"].values[0]), float(row[f"{metric_prefix}_std_dev"].values[0])

                cpp_m, cpp_s = get_stats("cpp")
                rust_m, rust_s = get_stats("rust")
                zig_m, zig_s = get_stats("zig")

                r_c = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, BUILD_SAMPLE_SIZE, cpp_m, cpp_s, BUILD_SAMPLE_SIZE)) if (rust_m is not None and cpp_m is not None) else "N/A"
                z_c = format_diff_cell(*compute_pct_and_pvalue(zig_m, zig_s, BUILD_SAMPLE_SIZE, cpp_m, cpp_s, BUILD_SAMPLE_SIZE)) if (zig_m is not None and cpp_m is not None) else "N/A"
                r_z = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, BUILD_SAMPLE_SIZE, zig_m, zig_s, BUILD_SAMPLE_SIZE)) if (rust_m is not None and zig_m is not None) else "N/A"

                latex.append(f"{metric_name} & {r_c} & {z_c} & {r_z} \\\\")

        latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
        return "\n".join(latex)

    # Helper: Within-language paradigm comparison
    def within_lang_table(raw_setting: str, friendly_setting: str) -> str:
        latex = [
            f"% ==================== WITHIN-LANGUAGE TABLE: {friendly_setting.upper()} ====================",
            r"\begin{table}[htbp]",
            r"\centering",
            f"\\caption{{Branching Build Within-Language Percentage Differences: Compile-Time vs. Runtime Branching Across All Metrics (Workload Setting: \\textbf{{{friendly_setting}}})}}",
            f"\\label{{tab:branching_build_within_lang_{friendly_setting}}}",
            r"\vspace{2pt}",
            r"\centerline{%",
            r"\small",
            r"\setlength{\tabcolsep}{6.0pt}",
            r"\begin{tabular}{l c c c}",
            r"\toprule",
            r"\textbf{Metric} & \textbf{C++} & \textbf{Rust} & \textbf{Zig} \\",
            r"\midrule"
        ]

        sub_cmp = df[(df["label"] == "image_pipeline_comptime") & (df["setting"] == raw_setting)]
        sub_run = df[(df["label"] == "image_pipeline_runtime") & (df["setting"] == raw_setting)]

        for metric_prefix, metric_name in BUILD_METRICS:
            cells = []
            for lang in ["cpp", "rust", "zig"]:
                row_cmp = sub_cmp[sub_cmp["lang"] == lang]
                row_run = sub_run[sub_run["lang"] == lang]

                if not row_cmp.empty and not row_run.empty:
                    m_cmp, s_cmp = float(row_cmp[f"{metric_prefix}_mean"].values[0]), float(row_cmp[f"{metric_prefix}_std_dev"].values[0])
                    m_run, s_run = float(row_run[f"{metric_prefix}_mean"].values[0]), float(row_run[f"{metric_prefix}_std_dev"].values[0])
                    pct_diff, p_val = compute_pct_and_pvalue(m_cmp, s_cmp, BUILD_SAMPLE_SIZE, m_run, s_run, BUILD_SAMPLE_SIZE)
                    cells.append(format_diff_cell(pct_diff, p_val))
                else:
                    cells.append("N/A")

            latex.append(f"{metric_name} & {cells[0]} & {cells[1]} & {cells[2]} \\\\")

        latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
        return "\n".join(latex)

    for raw_setting, friendly_setting in SETTING_MAP:
        output_tables.append(raw_stats_table(raw_setting, friendly_setting))
    for raw_setting, friendly_setting in SETTING_MAP:
        output_tables.append(pairwise_table(raw_setting, friendly_setting))
    for raw_setting, friendly_setting in SETTING_MAP:
        output_tables.append(within_lang_table(raw_setting, friendly_setting))

    return "\n".join(output_tables)

# -------------------------------------------------------------------------
# Main Execution
# -------------------------------------------------------------------------

def main():
    if RUNTIME_CSV_PATH.is_file():
        runtime_tex = generate_all_runtime_tables(RUNTIME_CSV_PATH)
        OUTPUT_RUNTIME_TEX.write_text(runtime_tex, encoding="utf-8")
        print(f"Generated Runtime Tables -> {OUTPUT_RUNTIME_TEX}")

    if BUILD_CSV_PATH.is_file():
        build_tex = generate_all_build_tables(BUILD_CSV_PATH)
        OUTPUT_BUILD_TEX.write_text(build_tex, encoding="utf-8")
        print(f"Generated Build Tables -> {OUTPUT_BUILD_TEX}")

if __name__ == "__main__":
    main()

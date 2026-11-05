from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

RUNTIME_CSV_PATH = Path("runtime_times_all.csv")
BUILD_CSV_PATH = Path("build_times_all.csv")

OUTPUT_RUNTIME_TEX = Path("generated_poly_runtime_tables.tex")
OUTPUT_BUILD_TEX = Path("generated_poly_build_tables.tex")
OUTPUT_CALIBRATION_TEX = Path("generated_calibration_table.tex")

RUNTIME_METRICS = [
    ("runtime_ns", "Runtime (ns)"),
    ("cycles", "Cycles"),
    ("instructions", "Instructions"),
    ("cache-misses", "Cache Misses"),
    ("cache-references", "Cache References"),
    ("branches", "Branches"),
    ("branch-misses", "Branch Misses"),
]

# Compact subset for calibration benchmarks matching your example style
CALIBRATION_METRICS = [
    ("runtime_ns", "Runtime (ns)"),
    ("instructions", "Instructions"),
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

RUNTIME_SAMPLE_SIZE = 30
BUILD_SAMPLE_SIZE = 15

# -------------------------------------------------------------------------
# Formatting & Statistics Helpers
# -------------------------------------------------------------------------

def format_latex_num(val: float) -> str:
    """Formats numbers with LaTeX thin spaces as thousands separators."""
    if pd.isna(val) or val is None or str(val).upper() == "N/A":
        return "N/A"
    try:
        f_val = float(val)
        if f_val >= 1000:
            return f"{f_val:,.2f}".replace(",", r"\,")
        return f"{f_val:.2f}"
    except ValueError:
        return str(val)

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
# Calibration Table Generator
# -------------------------------------------------------------------------

def generate_calibration_table(csv_path: Path) -> str:
    """Generates the raw benchmarks table for runtime calibration measurements."""
    if not csv_path.is_file():
        raise FileNotFoundError(f"Runtime CSV not found at {csv_path}")

    df = pd.read_csv(csv_path, na_filter=False)
    sub_df = df[df["label"] == "calibration"]

    latex = [
        "% ==================== Calibration Raw Benchmarks Table ====================",
        r"\begin{table}[htbp]",
        r"\centering",
        r"\footnotesize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\caption{Runtime Calibration Benchmarks Across Languages}",
        r"\label{tab:calibration_runtimes}",
        r"\centerline{%",
        r"\begin{tabular}{l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l}",
        r"\toprule",
        r"\textbf{Lang} & \multicolumn{2}{c}{\textbf{Runtime (ns)}} & \multicolumn{2}{c}{\textbf{Instructions}} & \multicolumn{2}{c}{\textbf{Branch Misses}} \\",
        r"\midrule"
    ]

    languages = [("cpp", "C++"), ("rust", "Rust"), ("zig", "Zig")]

    for lang_key, lang_name in languages:
        row = sub_df[sub_df["lang"] == lang_key]
        
        row_cells = [lang_name]
        for metric_prefix, _ in CALIBRATION_METRICS:
            if row.empty or pd.isna(row[f"{metric_prefix}_mean"].values[0]) or str(row[f"{metric_prefix}_mean"].values[0]).upper() == "N/A":
                row_cells.append(r"\multicolumn{2}{c}{N/A}")
            else:
                m = float(row[f"{metric_prefix}_mean"].values[0])
                s = float(row[f"{metric_prefix}_std_dev"].values[0])
                row_cells.append(f"{format_latex_num(m)} & {format_latex_num(s)}")
                
        latex.append(" & ".join(row_cells) + r" \\")

    latex.extend([
        r"\bottomrule",
        r"\end{tabular}%",
        r"}",
        r"\end{table}",
        "\n"
    ])

    return "\n".join(latex)

# -------------------------------------------------------------------------
# Polymorphism Tables Generators (Runtime & Build)
# -------------------------------------------------------------------------

def generate_poly_runtime_tables(csv_path: Path) -> str:
    """Generates decoupled LaTeX tables for raw runtime metrics and pairwise comparisons."""
    if not csv_path.is_file():
        raise FileNotFoundError(f"Runtime CSV not found at {csv_path}")

    df = pd.read_csv(csv_path, na_filter=False)

    sections = [
        ("poly_stat", "Static Polymorphism (poly\\_stat)"),
        ("poly_dyn", "Dynamic Polymorphism (poly\\_dyn)"),
    ]

    output_latex = []

    # 1. Raw Stats Table
    raw_latex = [
        "% ==================== Polymorphism Runtime Raw Stats Table ====================",
        r"\begin{table}[htbp]",
        r"\centering",
        r"\caption{Polymorphism Runtime Performance --- Raw Metrics}",
        r"\label{tab:poly_runtime_raw_stats}",
        r"\vspace{2pt}",
        r"\centerline{%",
        r"\small",
        r"\setlength{\tabcolsep}{6.0pt}",
        r"\begin{tabular}{l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l}",
        r"\toprule",
        r"\textbf{Metric} & \multicolumn{2}{c}{\textbf{C++}} & \multicolumn{2}{c}{\textbf{Rust}} & \multicolumn{2}{c}{\textbf{Zig}} \\"
    ]

    for label_key, sec_title in sections:
        sub_df = df[df["label"] == label_key]
        raw_latex.extend([r"\midrule", f"\\multicolumn{{7}}{{@{{}}l}}{{\\textbf{{\\small \\textit{{{sec_title}}}}}}} \\\\", r"\midrule"])

        for metric_prefix, metric_name in RUNTIME_METRICS:
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

            raw_latex.append(f"{metric_name} & {cpp_str} & {rust_str} & {zig_str} \\\\")

    raw_latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
    output_latex.append("\n".join(raw_latex))

    # 2. Pairwise Language Comparisons Table
    pairwise_latex = [
        "% ==================== Polymorphism Runtime Pairwise Comparisons Table ====================",
        r"\begin{table}[htbp]",
        r"\centering",
        r"\caption{Polymorphism Runtime Performance --- Pairwise Language Comparisons}",
        r"\label{tab:poly_runtime_pairwise}",
        r"\vspace{2pt}",
        r"\centerline{%",
        r"\small",
        r"\setlength{\tabcolsep}{6.0pt}",
        r"\begin{tabular}{l c c c}",
        r"\toprule",
        r"\textbf{Metric} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\"
    ]

    for label_key, sec_title in sections:
        sub_df = df[df["label"] == label_key]
        pairwise_latex.extend([r"\midrule", f"\\multicolumn{{4}}{{@{{}}l}}{{\\textbf{{\\small \\textit{{{sec_title}}}}}}} \\\\", r"\midrule"])

        for metric_prefix, metric_name in RUNTIME_METRICS:
            def get_stats(lang_name):
                row = sub_df[sub_df["lang"] == lang_name]
                if row.empty:
                    return None, None
                return float(row[f"{metric_prefix}_mean"].values[0]), float(row[f"{metric_prefix}_std_dev"].values[0])

            cpp_m, cpp_s = get_stats("cpp")
            rust_m, rust_s = get_stats("rust")
            zig_m, zig_s = get_stats("zig")

            r_c = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, RUNTIME_SAMPLE_SIZE, cpp_m, cpp_s, RUNTIME_SAMPLE_SIZE)) if (rust_m is not None and cpp_m is not None) else "N/A"
            z_c = format_diff_cell(*compute_pct_and_pvalue(zig_m, zig_s, RUNTIME_SAMPLE_SIZE, cpp_m, cpp_s, RUNTIME_SAMPLE_SIZE)) if (zig_m is not None and cpp_m is not None) else "N/A"
            r_z = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, RUNTIME_SAMPLE_SIZE, zig_m, zig_s, RUNTIME_SAMPLE_SIZE)) if (rust_m is not None and zig_m is not None) else "N/A"

            pairwise_latex.append(f"{metric_name} & {r_c} & {z_c} & {r_z} \\\\")

    pairwise_latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
    output_latex.append("\n".join(pairwise_latex))

    return "\n".join(output_latex)

def generate_poly_build_table(csv_path: Path) -> str:
    """Generates a single unified LaTeX table for polymorphism build performance."""
    if not csv_path.is_file():
        raise FileNotFoundError(f"Build CSV not found at {csv_path}")

    df = pd.read_csv(csv_path, na_filter=False)

    sections = [
        ("poly_stat", "Static Polymorphism (poly\\_stat)"),
        ("poly_dyn", "Dynamic Polymorphism (poly\\_dyn)"),
    ]

    latex = [
        "% ==================== Polymorphism Build Performance Table ====================",
        r"\begin{table}[htbp]",
        r"\centering",
        r"\caption{Polymorphism Build Performance --- Raw Metrics and Inter-Language Comparisons}",
        r"\label{tab:poly_build_performance}",
        r"\vspace{2pt}",
        r"\centerline{%",
        r"\small",
        r"\setlength{\tabcolsep}{1.2pt}",
        r"\begin{tabular}{l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l c c c}",
        r"\toprule",
        r"\textbf{Metric} & \multicolumn{2}{c}{\textbf{C++ (s)}} & \multicolumn{2}{c}{\textbf{Rust (s)}} & \multicolumn{2}{c}{\textbf{Zig (s)}} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} & \textbf{Rust vs. Zig} \\"
    ]

    for label_key, sec_title in sections:
        sub_df = df[df["label"] == label_key]
        latex.extend([r"\midrule", f"\\multicolumn{{10}}{{@{{}}l}}{{\\textbf{{\\small \\textit{{{sec_title}}}}}}} \\\\", r"\midrule"])

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

            r_c = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, BUILD_SAMPLE_SIZE, cpp_m, cpp_s, BUILD_SAMPLE_SIZE)) if (rust_m is not None and cpp_m is not None) else "N/A"
            z_c = format_diff_cell(*compute_pct_and_pvalue(zig_m, zig_s, BUILD_SAMPLE_SIZE, cpp_m, cpp_s, BUILD_SAMPLE_SIZE)) if (zig_m is not None and cpp_m is not None) else "N/A"
            r_z = format_diff_cell(*compute_pct_and_pvalue(rust_m, rust_s, BUILD_SAMPLE_SIZE, zig_m, zig_s, BUILD_SAMPLE_SIZE)) if (rust_m is not None and zig_m is not None) else "N/A"

            latex.append(f"{metric_name} & {cpp_str} & {rust_str} & {zig_str} & {r_c} & {z_c} & {r_z} \\\\")

    latex.extend([r"\bottomrule", r"\end{tabular}%", r"}", r"\end{table}", "\n"])
    return "\n".join(latex)

# -------------------------------------------------------------------------
# Main Execution
# -------------------------------------------------------------------------

def main():
    if RUNTIME_CSV_PATH.is_file():
        runtime_tex = generate_poly_runtime_tables(RUNTIME_CSV_PATH)
        OUTPUT_RUNTIME_TEX.write_text(runtime_tex, encoding="utf-8")
        print(f"Generated Runtime Tables -> {OUTPUT_RUNTIME_TEX}")

        calibration_tex = generate_calibration_table(RUNTIME_CSV_PATH)
        OUTPUT_CALIBRATION_TEX.write_text(calibration_tex, encoding="utf-8")
        print(f"Generated Calibration Table -> {OUTPUT_CALIBRATION_TEX}")

    if BUILD_CSV_PATH.is_file():
        build_tex = generate_poly_build_table(BUILD_CSV_PATH)
        OUTPUT_BUILD_TEX.write_text(build_tex, encoding="utf-8")
        print(f"Generated Build Table -> {OUTPUT_BUILD_TEX}")

if __name__ == "__main__":
    main()

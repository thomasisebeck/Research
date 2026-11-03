from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")
OUTPUT_TEX = Path("generated_poly_tables.tex")

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


def compute_pct_and_pvalue(
    mean_a: float,
    std_a: float,
    n_a: int,
    mean_b: float,
    std_b: float,
    n_b: int,
):
    """Calculates percentage difference (A vs B) and Welch's t-test p-value.

    Percentage diff = ((mean_a - mean_b) / mean_b) * 100
    """
    if mean_b == 0 or pd.isna(mean_a) or pd.isna(mean_b):
        return 0.0, 1.0

    pct_diff = ((mean_a - mean_b) / mean_b) * 100.0

    # Welch's t-test from summary stats
    se_a = (std_a**2) / n_a
    se_b = (std_b**2) / n_b
    se_diff = np.sqrt(se_a + se_b)

    if se_diff == 0:
        p_val = 1.0
    else:
        t_stat = (mean_a - mean_b) / se_diff
        df_num = (se_a + se_b) ** 2
        df_denom = (se_a**2) / (n_a - 1) + (se_b**2) / (n_b - 1)
        df = df_num / df_denom if df_denom > 0 else (n_a + n_b - 2)
        p_val = stats.t.sf(np.abs(t_stat), df) * 2

    return pct_diff, p_val


def format_diff_cell(pct_diff: float, p_val: float) -> str:
    """Formats percentage change and p-value with bolding if p < 0.05."""
    sign = "+" if pct_diff > 0 else ""
    p_str = "$p < 0.001$" if p_val < 0.001 else f"$p = {p_val:.3f}$"
    val_str = f"{sign}{pct_diff:.2f}\\%"

    if p_val < 0.05:
        bold_val = f"\\textbf{{{val_str}}}"
        return f"{bold_val} ({p_str})"
    else:
        return f"{val_str} ({p_str})"


# -------------------------------------------------------------------------
# Table Generators
# -------------------------------------------------------------------------

def generate_between_language_poly_table(df: pd.DataFrame) -> str:
    """Generates a single combined between-language statistical significance
    table covering both Static (poly_stat) and Dynamic (poly_dyn) dispatch.
    """
    latex = []
    latex.append(
        "% ==================== Polymorphism Between-Language Comparison"
        " ===================="
    )
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(
        r"\caption{Polymorphism Between-Language Statistical Significance and"
        r" Percentage Differences ($H_1: \text{Lang}_A \neq \text{Lang}_B$)}"
    )
    latex.append(r"\label{tab:poly_between_lang}")
    latex.append(r"\begin{tabular}{l ccc}")
    latex.append(r"\toprule")
    latex.append(
        r"\textbf{Metric} & \textbf{Rust vs. C++} & \textbf{Zig vs. C++} &"
        r" \textbf{Rust vs. Zig} \\"
    )

    sections = [
        ("poly_stat", "Static Polymorphism (poly\\_stat)"),
        ("poly_dyn", "Dynamic Polymorphism (poly\\_dyn)"),
    ]

    for label, sec_title in sections:
        sub_df = df[df["label"] == label]

        latex.append(r"\midrule")
        latex.append(
            r"\multicolumn{4}{c}{\textbf{\textit{" + sec_title + r"}}} \\"
        )
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

            rust_cpp_pct, rust_cpp_p = compute_pct_and_pvalue(
                rust_m, rust_s, rust_n, cpp_m, cpp_s, cpp_n
            )
            zig_cpp_pct, zig_cpp_p = compute_pct_and_pvalue(
                zig_m, zig_s, zig_n, cpp_m, cpp_s, cpp_n
            )
            rust_zig_pct, rust_zig_p = compute_pct_and_pvalue(
                rust_m, rust_s, rust_n, zig_m, zig_s, zig_n
            )

            cell_rust_cpp = format_diff_cell(rust_cpp_pct, rust_cpp_p)
            cell_zig_cpp = format_diff_cell(zig_cpp_pct, zig_cpp_p)
            cell_rust_zig = format_diff_cell(rust_zig_pct, rust_zig_p)

            latex.append(
                f"{metric_name:18s} & {cell_rust_cpp} & {cell_zig_cpp} &"
                f" {cell_rust_zig} \\\\"
            )

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular}")
    latex.append(r"\end{table}")
    latex.append("\n")

    return "\n".join(latex)


def generate_within_language_poly_table(df: pd.DataFrame) -> str:
    """Generates a within-language dispatch comparison table for ALL metrics,

    comparing Static (poly_stat) against Dynamic (poly_dyn) dispatch per
    language.
    """
    sub_dyn = df[df["label"] == "poly_dyn"]
    sub_stat = df[df["label"] == "poly_stat"]

    latex = []
    latex.append(
        "% ==================== Polymorphism Within-Language Comparison ===================="
    )
    latex.append(r"\begin{table}[htbp]")
    latex.append(r"\centering")
    latex.append(
        r"\caption{Polymorphism Within-Language Percentage Differences: Static (\texttt{poly\_stat}) vs. Dynamic (\texttt{poly\_dyn}) Dispatch Across All Metrics}"
    )
    latex.append(r"\label{tab:poly_within_lang}")
    latex.append(r"\begin{tabular}{l ccc}")
    latex.append(r"\toprule")
    latex.append(
        r"\textbf{Metric} & \textbf{C++} & \textbf{Rust} & \textbf{Zig} \\"
    )

    langs = [("cpp", "C++"), ("rust", "Rust"), ("zig", "Zig")]
    n_obs = 30

    latex.append(r"\midrule")

    for metric_key, metric_name in METRICS:
        cells = []
        for lang_code, lang_disp in langs:
            row_dyn = sub_dyn[sub_dyn["lang"] == lang_code]
            row_stat = sub_stat[sub_stat["lang"] == lang_code]

            if not row_dyn.empty and not row_stat.empty:
                dyn_m = float(row_dyn[f"{metric_key}_mean"].values[0])
                dyn_s = float(row_dyn[f"{metric_key}_std_dev"].values[0])
                stat_m = float(row_stat[f"{metric_key}_mean"].values[0])
                stat_s = float(row_stat[f"{metric_key}_std_dev"].values[0])

                # Percentage difference = ((Static - Dynamic) / Dynamic) * 100
                pct_diff, p_val = compute_pct_and_pvalue(
                    stat_m, stat_s, n_obs, dyn_m, dyn_s, n_obs
                )
                cells.append(format_diff_cell(pct_diff, p_val))
            else:
                cells.append("N/A")

        latex.append(
            f"{metric_name:18s} & {cells[0]} & {cells[1]} & {cells[2]} \\\\"
        )

    latex.append(r"\bottomrule")
    latex.append(r"\end{tabular}")
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

    # 1. Between-Language Comparison (Combines poly_stat and poly_dyn)
    output_tables.append(generate_between_language_poly_table(df))

    # 2. Within-Language Comparison (All Metrics: Static vs. Dynamic)
    output_tables.append(generate_within_language_poly_table(df))

    full_tex_content = "\n".join(output_tables)

    with open(OUTPUT_TEX, "w", encoding="utf-8") as f:
        f.write(full_tex_content)

    print(
        f"Successfully generated polymorphism LaTeX tables to: {OUTPUT_TEX}"
    )


if __name__ == "__main__":
    main()

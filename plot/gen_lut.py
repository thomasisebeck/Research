from pathlib import Path
import re
import numpy as np
import pandas as pd
from scipy import stats

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")
OUTPUT_TEX = Path("generated_lut_tables.tex")

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

def parse_increment_val(setting_str: str) -> float:
    """Extracts numeric value from INC_X format for proper sorting."""
    match = re.search(r"INC_([\d.]+)", str(setting_str))
    return float(match.group(1)) if match else -1.0

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
    """Formats percentage change and p-value with bolding if p < 0.05."""
    sign = "+" if pct_diff > 0 else ""
    p_str = "$p < 0.001$" if p_val < 0.001 else f"$p = {p_val:.3f}$"
    val_str = f"{sign}{pct_diff:.2f}\\%"
    
    if p_val < 0.05:
        return f"\\textbf{{{val_str}}} ({p_str})"
    else:
        return f"{val_str} ({p_str})"

# -------------------------------------------------------------------------
# Table Generator
# -------------------------------------------------------------------------

def generate_stat_diff_table(df: pd.DataFrame, label: str, setting: str | None, title: str, tex_label: str) -> str:
    """
    Generates 4-column statistical significance comparison LaTeX tables for LUT benchmarks.
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
            if row.empty or pd.isna(row[f"{metric_key}_mean"].values[0]) or row[f"{metric_key}_mean"].values[0] == 0:
                return None, None, n_obs
            m = row[f"{metric_key}_mean"].values[0]
            s = row[f"{metric_key}_std_dev"].values[0]
            return float(m), float(s), n_obs

        cpp_m, cpp_s, cpp_n = get_stats("cpp")
        rust_m, rust_s, rust_n = get_stats("rust")
        zig_m, zig_s, zig_n = get_stats("zig")

        # Process Rust vs C++
        if rust_m is not None and cpp_m is not None:
            r_c_pct, r_c_p = compute_pct_and_pvalue(rust_m, rust_s, rust_n, cpp_m, cpp_s, cpp_n)
            cell_rust_cpp = format_diff_cell(r_c_pct, r_c_p)
        else:
            cell_rust_cpp = "N/A"

        # Process Zig vs C++
        if zig_m is not None and cpp_m is not None:
            z_c_pct, z_c_p = compute_pct_and_pvalue(zig_m, zig_s, zig_n, cpp_m, cpp_s, cpp_n)
            cell_zig_cpp = format_diff_cell(z_c_pct, z_c_p)
        else:
            cell_zig_cpp = "N/A"

        # Process Rust vs Zig
        if rust_m is not None and zig_m is not None:
            r_z_pct, r_z_p = compute_pct_and_pvalue(rust_m, rust_s, rust_n, zig_m, zig_s, zig_n)
            cell_rust_zig = format_diff_cell(r_z_pct, r_z_p)
        else:
            cell_rust_zig = "N/A"

        latex.append(f"{metric_name} & {cell_rust_cpp} & {cell_zig_cpp} & {cell_rust_zig} \\\\")

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
        print(f"Error: CSV file not found at {CSV_PATH}.")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)
    output_tables = []

    # 1. Lookup Table Runtime (lut_runtime - aggregated across all settings if setting=None or per setting)
    runtime_settings = df[df["label"] == "lut_runtime"]["setting"].unique()
    if len(runtime_settings) == 1 and runtime_settings[0] in ["", "N/A"]:
        output_tables.append(generate_stat_diff_table(
            df, "lut_runtime", None, "Lookup Table (Runtime)", "tab:lut_runtime"
        ))
    else:
        for setting in sorted(runtime_settings, key=parse_increment_val, reverse=True):
            clean_setting = setting.replace("INC_", "").replace(".", "_")
            output_tables.append(generate_stat_diff_table(
                df, "lut_runtime", setting, f"Lookup Table Runtime ({setting})", f"tab:lut_runtime_{clean_setting}"
            ))

    # 2. Lookup Table Comptime (lut_comptime - per increment setting)
    comptime_settings = sorted(
        df[df["label"] == "lut_comptime"]["setting"].unique(),
        key=parse_increment_val,
        reverse=True
    )

    for setting in comptime_settings:
        clean_setting = setting.replace("INC_", "").replace(".", "_")
        output_tables.append(generate_stat_diff_table(
            df, "lut_comptime", setting, f"Lookup Table Comptime ({setting})", f"tab:lut_comptime_{clean_setting}"
        ))

    full_tex_content = "\n".join(output_tables)

    with open(OUTPUT_TEX, "w", encoding="utf-8") as f:
        f.write(full_tex_content)

    print(f"Successfully generated all LUT LaTeX tables to: {OUTPUT_TEX}")

if __name__ == "__main__":
    main()

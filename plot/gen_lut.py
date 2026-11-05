from pathlib import Path
import re
import numpy as np
import pandas as pd

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

CSV_PATH = Path("runtime_times_all.csv")
OUTPUT_TEX = Path("generated_lut_massive_comptime_table.tex")

SAMPLE_SIZE_N = 30  # Standard sample size per benchmark run

# -------------------------------------------------------------------------
# Formatting Helpers
# -------------------------------------------------------------------------

def format_latex_num(val: float) -> str:
    """Formats numbers with LaTeX thin spaces as thousands separators."""
    if pd.isna(val) or val is None:
        return "N/A"
    if val >= 1000:
        return f"{val:,.2f}".replace(",", r"\,")
    return f"{val:.2f}"

def parse_increment_val(setting_str: str) -> float:
    """Extracts numeric value from INC_X format for proper sorting."""
    match = re.search(r"INC_([\d.]+)", str(setting_str))
    return float(match.group(1)) if match else -1.0

# -------------------------------------------------------------------------
# Massive Table Generator
# -------------------------------------------------------------------------

def generate_massive_comptime_table(df: pd.DataFrame, output_path: Path):
    """
    Generates a single massive LaTeX table containing all increments for
    compile-time lookup table raw stats across C++, Rust, and Zig.
    """
    sub_df = df[df["label"] == "lut_comptime"]
    
    # Get all unique settings sorted by increment value descending
    settings = sorted(
        sub_df["setting"].unique(),
        key=parse_increment_val,
        reverse=True
    )

    latex = [
        "% ==================== Massive Comptime Raw Stats Table ====================",
        r"\begin{table}[htbp]",
        r"\centering",
        r"\footnotesize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\caption{Lookup Table Comptime --- Raw Benchmarks Across All Increment Settings ($\Delta$)}",
        r"\label{tab:lut_comptime_massive_raw}",
        r"\centerline{%",
        r"\begin{tabular}{l l r@{\,$\pm$\,}l r@{\,$\pm$\,}l r@{\,$\pm$\,}l}",
        r"\toprule",
        r"\textbf{Increment} & \textbf{Lang} & \multicolumn{2}{c}{\textbf{Runtime (ns)}} & \multicolumn{2}{c}{\textbf{Instructions}} & \multicolumn{2}{c}{\textbf{Branch Misses}} \\",
        r"\midrule"
    ]

    languages = [("cpp", "C++"), ("rust", "Rust"), ("zig", "Zig")]

    for idx, setting in enumerate(settings):
        delta_val = setting.replace("INC_", "") if "INC_" in setting else setting
        setting_sub = sub_df[sub_df["setting"] == setting]
        
        for lang_idx, (lang_key, lang_name) in enumerate(languages):
            row = setting_sub[setting_sub["lang"] == lang_key]
            
            def get_stat(metric):
                if row.empty or pd.isna(row[f"{metric}_mean"].values[0]):
                    return 0.0, 0.0
                return float(row[f"{metric}_mean"].values[0]), float(row[f"{metric}_std_dev"].values[0])

            rt_m, rt_s = get_stat("runtime_ns")
            ins_m, ins_s = get_stat("instructions")
            bm_m, bm_s = get_stat("branch-misses")

            rt_str = f"{format_latex_num(rt_m)} & {format_latex_num(rt_s)}"
            ins_str = f"{format_latex_num(ins_m)} & {format_latex_num(ins_s)}"
            bm_str = f"{format_latex_num(bm_m)} & {format_latex_num(bm_s)}"

            # Display increment label only on the first language row of each block
            inc_label = f"$\Delta = {delta_val}$" if lang_idx == 0 else ""
            
            latex.append(f"{inc_label} & {lang_name} & {rt_str} & {ins_str} & {bm_str} \\\\")

        # Add a midrule between different increment blocks
        if idx < len(settings) - 1:
            latex.append(r"\midrule")

    latex.extend([
        r"\bottomrule",
        r"\end{tabular}%",
        r"}",
        r"\end{table}",
        "\n"
    ])

    output_path.write_text("\n".join(latex), encoding="utf-8")
    print(f"Generated massive comptime raw stats table -> {output_path}")

# -------------------------------------------------------------------------
# Main Execution
# -------------------------------------------------------------------------

def main():
    if not CSV_PATH.is_file():
        print(f"Error: CSV file not found at {CSV_PATH}.")
        return

    df = pd.read_csv(CSV_PATH, na_filter=False)
    generate_massive_comptime_table(df, OUTPUT_TEX)

if __name__ == "__main__":
    main()

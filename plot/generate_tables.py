import os
import csv
import argparse
import pandas as pd

def format_table(csv_path, format_type='markdown'):
    if not os.path.exists(csv_path):
        print(f"File not found: {csv_path}")
        return
        
    df = pd.read_csv(csv_path)
    
    # Select key reporting columns if they exist
    key_cols = ['lang', 'label', 'setting', 'runtime_ns_mean', 'cycles_mean', 'instructions_mean']
    available_cols = [col for col in key_cols if col in df.columns]
    
    report_df = df[available_cols].copy()
    
    # Rename columns for presentation
    rename_map = {
        'lang': 'Language',
        'label': 'Experiment',
        'setting': 'Setting',
        'runtime_ns_mean': 'Runtime (ns)',
        'cycles_mean': 'Cycles',
        'instructions_mean': 'Instructions'
    }
    report_df.rename(columns=rename_map, inplace=True)
    
    if format_type == 'latex':
        output = report_df.to_latex(index=False, float_format="%.2f")
    else:
        output = report_df.to_markdown(index=False)
        
    print(f"\n--- Generated Table ({format_type.upper()}) ---")
    print(output)
    print("-" * 40)

def main():
    parser = argparse.ArgumentParser(description="Generate publication tables from aggregated CSVs.")
    parser.add_argument("--format", choices=['markdown', 'latex'], default='markdown', help="Table output format")
    args = parser.parse_args()
    
    format_table('runtime_times_all.csv', args.format)

if __name__ == "__main__":
    main()

import os
import csv
import argparse
import statistics
from collections import defaultdict

def process_file(input_filename, output_filename, experiment_name):
    langs = ['cpp', 'rust', 'zig']
    
    # Structure: grouped_data[(lang, label, setting)][metric_name] = [val1, val2, ...]
    grouped_data = defaultdict(lambda: defaultdict(list))
    metrics_order = []
    
    for lang in langs:
        filepath = os.path.join(lang, input_filename)
        
        if not os.path.exists(filepath):
            print(f"Skipping {filepath} (file not found)")
            continue
            
        with open(filepath, 'r', newline='') as f:
            reader = csv.DictReader(f)
            
            # Dynamically identify the metric columns (everything except label, setting, run_number)
            if not metrics_order and reader.fieldnames:
                standard_cols = {'label', 'setting', 'run_number'}
                metrics_order = [col for col in reader.fieldnames if col not in standard_cols]
                
            for row in reader:
                # Filter by experiment name (case-insensitive partial match for convenience)
                if experiment_name.lower() not in row['label'].lower():
                    continue
                    
                key = (lang, row['label'], row['setting'])
                
                # Gather all metrics for this row
                for metric in metrics_order:
                    if metric in row and row[metric].strip():
                        grouped_data[key][metric].append(float(row[metric]))

    if not grouped_data:
        print(f"No data found for '{experiment_name}' in {input_filename}.")
        return

    # Prepare output headers
    out_headers = ['lang', 'label', 'setting']
    for metric in metrics_order:
        out_headers.extend([f"{metric}_mean", f"{metric}_std_dev", f"{metric}_variance"])
        
    # Check if target file already exists and is non-empty
    file_exists = os.path.exists(output_filename) and os.path.getsize(output_filename) > 0

    # Append to file if it exists, otherwise create it
    with open(output_filename, 'a', newline='') as f:
        writer = csv.writer(f)
        
        # Write header only if the file is new or empty
        if not file_exists:
            writer.writerow(out_headers)
        
        for (lang, label, setting), metrics_dict in grouped_data.items():
            out_row = [lang, label, setting]
            
            for metric in metrics_order:
                values = metrics_dict.get(metric, [])
                
                if not values:
                    # Fallback if a metric is entirely missing
                    out_row.extend(['', '', ''])
                else:
                    mean = statistics.mean(values)
                    # std_dev and variance require at least 2 data points
                    if len(values) > 1:
                        std_dev = statistics.stdev(values)
                        variance = statistics.variance(values)
                    else:
                        std_dev = 0.0
                        variance = 0.0
                        
                    out_row.extend([round(mean, 2), round(std_dev, 2), round(variance, 2)])
                    
            writer.writerow(out_row)
            
    print(f"Successfully appended aggregated data to {output_filename}")

def main():
    parser = argparse.ArgumentParser(description="Aggregate build and runtime metrics across languages.")
    parser.add_argument("experiment", help="The experiment name to filter by (e.g., 'calibration', 'image_pipeline_runtime')")
    args = parser.parse_args()

    process_file('runtime.csv', 'runtime_times_all.csv', args.experiment)
    process_file('build_times.csv', 'build_times_all.csv', args.experiment)

if __name__ == "__main__":
    main()

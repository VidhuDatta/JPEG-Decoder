def process_and_shift_columns(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    processed_data = []

    # Extract columns from each line after removing first and last columns
    for line in lines:
        parts = line.strip().split()
        if len(parts) < 3:
            continue
        # Remove first and last column
        middle_columns = parts[1:7]
        processed_data.extend(middle_columns)

    # Now split processed_data into chunks of 4 columns
    output_lines = []
    for i in range(0, len(processed_data), 4):
        chunk = processed_data[i:i+4]
        # Pad with '0's if chunk is less than 4
        if len(chunk) < 4:
            chunk.extend(['00000000'] * (4 - len(chunk)))
        output_lines.append(' '.join(chunk))

    # Write to output file
    with open(output_file, 'w') as f:
        for line in output_lines:
            f.write(line + '\n')

    return output_lines

# Example usage
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 3:
        print("Usage: python script.py input_file output_file")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    output = process_and_shift_columns(input_file, output_file)
    print(f"Processing complete. Output saved to '{output_file}'")

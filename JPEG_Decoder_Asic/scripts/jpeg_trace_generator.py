import argparse

def binary_to_trace(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    with open(output_file, 'w') as f:
        # Write header comment
        f.write("# JPEG Decoder Trace File\n\n")
        
        # Write initial wait cycles
        f.write("# Wait 3 Cycles (Opcode 0000)\n")
        for _ in range(3):
            f.write("0000_0_0000_" + "0"*51 + "__" + "0"*32 + "\n")
        f.write("\n# JPEG Data\n")
        
        # Process each line of binary data
        for i, line in enumerate(lines):
            # Clean up the line (remove whitespace)
            binary_data = ''.join(line.strip().split()[::-1])
            
            # Make sure we have 32 bits
            if len(binary_data) != 32:
                continue
                
            # Set last bit to 1 if this is the final line
            last_bit = "1" if i == len(lines) - 1 else "0"
            
            # Format the trace line
            trace_line = f"0001_{last_bit}_1111_{'0'*51}__{binary_data}\n"
            f.write(trace_line)
        
        # Add end simulation command
        f.write("\n# Wait for response\n")
        f.write("0000_0_0000_" + "0"*51 + "__" + "0"*32 + "\n")
        f.write("\n# Expect output\n")
        f.write("0100_0_0000_" + "0"*51 + "__" + "0"*32 + "\n")
        f.write("\n# End simulation\n")
        f.write("0101_0_0000_" + "0"*51 + "__" + "0"*32 + "\n")

def main():
    # Set up command line argument parsing
    parser = argparse.ArgumentParser(description='Convert binary file to JPEG decoder trace format')
    parser.add_argument('--input', '-i', required=True, help='Input binary file path')
    parser.add_argument('--output', '-o', required=True, help='Output trace file path')
    
    # Parse arguments
    args = parser.parse_args()
    
    # Call the conversion function with the provided arguments
    print(f"Converting {args.input} to trace format...")
    binary_to_trace(args.input, args.output)
    print(f"Trace file created at {args.output}")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
#  ^ Shebang line to make the script executable (optional, for Unix-like systems)

import argparse
from PIL import Image
import os

def parse_trace_line(line_content):
    """
    Parses a single 88-bit trace line.
    Returns a tuple: (img_width, img_height, x, y, r, g, b)
    Returns None if the line is not a valid 88-bit binary string.
    """
    # Ensure the line is exactly 88 characters and contains only '0' or '1'
    if len(line_content) != 88 or not all(c in '01' for c in line_content):
        return None
    
    try:
        # Extract and convert binary segments to integers
        # Bits 0-15: Image Width
        img_width = int(line_content[0:16], 2)
        # Bits 16-31: Image Height
        img_height = int(line_content[16:32], 2)
        # Bits 32-47: Pixel X coordinate
        x = int(line_content[32:48], 2)
        # Bits 48-63: Pixel Y coordinate
        y = int(line_content[48:64], 2)
        # Bits 64-71: Red channel value (8-bit)
        r = int(line_content[64:72], 2)
        # Bits 72-79: Green channel value (8-bit)
        g = int(line_content[72:80], 2)
        # Bits 80-87: Blue channel value (8-bit)
        b = int(line_content[80:88], 2)
        return img_width, img_height, x, y, r, g, b
    except ValueError:
        # This should ideally not happen if the 88-bit binary check passes,
        # but it's good practice to catch potential errors during int conversion.
        print(f"Error: Could not convert binary segment to integer in line: {line_content}")
        return None

def create_image_from_trace(trace_file_path, output_image_path):
    """
    Reads a trace file, reconstructs an RGB image, and saves it.
    The trace file is expected to contain lines of 88-bit binary strings,
    where each string encodes image dimensions, pixel coordinates, and RGB values.
    Format: out_width(16)out_height(16)pixel_x(16)pixel_y(16)R(8)G(8)B(8)
    """
    image = None
    image_width = 0
    image_height = 0
    pixels_set = 0
    lines_processed = 0
    valid_data_lines = 0
    header_comments = []

    # Check if the input trace file exists
    if not os.path.exists(trace_file_path):
        print(f"Error: Trace file not found at '{trace_file_path}'")
        return False # Indicate failure

    print(f"Processing trace file: '{trace_file_path}'")

    # Open and read the trace file line by line
    with open(trace_file_path, 'r') as f:
        for line_number, line_content in enumerate(f, 1):
            line_content = line_content.strip() # Remove leading/trailing whitespace

            if not line_content: # Skip empty lines
                continue
            
            # Store and skip comment lines (lines starting with '#')
            if line_content.startswith('#'):
                header_comments.append(line_content)
                # print(f"Skipping comment line {line_number}: {line_content[:60]}...")
                continue

            lines_processed += 1
            parsed_data = parse_trace_line(line_content)

            if not parsed_data:
                print(f"Warning: Skipping invalid data format on line {line_number}. Line content (first 30 chars): '{line_content[:30]}...'")
                continue

            valid_data_lines +=1
            current_img_width, current_img_height, px, py, r_val, g_val, b_val = parsed_data

            # Initialize the image object on the first valid data line
            if image is None:
                image_width = current_img_width
                image_height = current_img_height
                
                # Validate parsed image dimensions
                if image_width <= 0 or image_height <= 0:
                    print(f"Error: Invalid image dimensions ({image_width}x{image_height}) "
                          f"parsed from the first valid data line (line {line_number}). Cannot create image.")
                    return False # Indicate failure
                
                print(f"Initializing image with dimensions: {image_width}x{image_height} (derived from line {line_number})")
                try:
                    # Create a new RGB image, defaulting to a black background
                    image = Image.new('RGB', (image_width, image_height), (0, 0, 0))
                except ValueError as e:
                    print(f"Error creating image with dimensions {image_width}x{image_height}: {e}")
                    return False # Indicate failure
                except Exception as e: # Catch other potential PIL errors
                    print(f"An unexpected error occurred while creating the image: {e}")
                    return False


            # Optional: Check for consistency in reported image dimensions on subsequent lines
            elif current_img_width != image_width or current_img_height != image_height:
                print(f"Warning: Inconsistent image dimensions on line {line_number}. "
                      f"Expected {image_width}x{image_height}, but line reports {current_img_width}x{current_img_height}. "
                      f"Using original dimensions ({image_width}x{image_height}) and processing pixel ({px},{py}).")
            
            # Set pixel data if coordinates are within image bounds
            if image: # Ensure image was successfully initialized
                if 0 <= px < image_width and 0 <= py < image_height:
                    image.putpixel((px, py), (r_val, g_val, b_val))
                    pixels_set += 1
                else:
                    print(f"Warning: Pixel coordinates ({px},{py}) on line {line_number} are out of "
                          f"bounds for image size ({image_width}x{image_height}). Skipping this pixel.")

    # After processing all lines, save the image if it was created
    if image:
        try:
            image.save(output_image_path)
            print(f"\nImage successfully saved to '{output_image_path}'")
            print(f"--- Summary ---")
            if header_comments:
                print(f"  Header comments from trace file:")
                for comment in header_comments:
                    print(f"    {comment}")
            print(f"  Image Dimensions: {image_width}x{image_height}")
            print(f"  Total lines read (excluding comments/empty): {lines_processed}")
            print(f"  Valid data lines processed: {valid_data_lines}")
            print(f"  Pixels set in image: {pixels_set}")
            
            expected_pixels = image_width * image_height
            if pixels_set == 0 and valid_data_lines > 0:
                 print(f"  Warning: No pixels were actually set, though {valid_data_lines} valid data lines were processed. "
                       "Please check coordinate values in your trace file.")
            elif 0 < pixels_set < expected_pixels :
                print(f"  Note: {pixels_set} pixels were set. The image might be sparse, "
                      f"or some pixel data might have been missing, out of bounds, or duplicated. "
                      f"A full image would have {expected_pixels} pixels.")
            elif pixels_set == expected_pixels:
                print(f"  All {expected_pixels} pixels for the image dimensions were set.")
            return True # Indicate success

        except Exception as e:
            print(f"Error saving image to '{output_image_path}': {e}")
            return False # Indicate failure
            
    elif lines_processed > 0 and valid_data_lines == 0:
        print("\nNo valid data lines found in the trace file. Image not created.")
        print(f"  Total lines read (excluding comments/empty): {lines_processed}")
        return False # Indicate failure
    elif lines_processed == 0 and not header_comments:
        print("\nTrace file appears to be empty or contains no processable content. Image not created.")
        return False
    elif lines_processed == 0 and header_comments:
        print("\nTrace file contains only comments. No pixel data found. Image not created.")
        return False
    else: # Should not be reached if logic is correct, but as a fallback
        print("\nNo image data was processed from the trace file. Image not created.")
        return False # Indicate failure

def main():
    """
    Main function to parse command-line arguments and run the conversion.
    """
    parser = argparse.ArgumentParser(
        description="Convert a trace file (containing 88-bit binary strings per pixel) to an RGB image.",
        formatter_class=argparse.RawTextHelpFormatter, # Allows for better formatting of help text
        epilog="""
Example usage:
  python script_name.py my_trace_data.tr
  python script_name.py path/to/another_trace.tr -o custom_output_name.png

The trace file format expected per data line (88 bits):
  out_width(16)out_height(16)pixel_x(16)pixel_y(16)R(8)G(8)B(8)
  - Each segment is a binary number.
  - Lines starting with '#' are treated as comments and ignored.
  - Empty lines are ignored.
"""
    )
    
    # Required argument: input trace file path
    parser.add_argument(
        "input_file", 
        type=str,
        help="Path to the input trace file (e.g., .tr or .txt)."
    )
    
    # Optional argument: output image file path
    parser.add_argument(
        "-o", "--output",
        dest="output_file",
        type=str,
        help="Path for the output image file (e.g., output.png). \n"
             "If not specified, it defaults to the input file name with a .png extension."
    )

    args = parser.parse_args()

    input_trace_file = args.input_file
    output_image_file = args.output_file

    # If output_file is not specified, create a default name
    if not output_image_file:
        base_name = os.path.splitext(input_trace_file)[0] # Get filename without extension
        output_image_file = base_name + ".png"

    print("Starting trace to image conversion...")
    success = create_image_from_trace(input_trace_file, output_image_file)
    
    if success:
        print("\nConversion process finished successfully.")
    else:
        print("\nConversion process finished with errors.")

if __name__ == '__main__':
    main()

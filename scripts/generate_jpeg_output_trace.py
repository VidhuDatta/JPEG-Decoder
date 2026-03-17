from PIL import Image
import argparse

def get_rgb_from_jpeg(jpeg_filepath):
    """
    Decodes a JPEG image and returns its dimensions and raw RGB pixel data.
    Pixel data is returned as a flat list of (R, G, B) tuples, in scanline order.
    """
    try:
        img = Image.open(jpeg_filepath)
        img_rgb = img.convert('RGB')
        width, height = img_rgb.size
        pixel_data = list(img_rgb.getdata())  # List of (R, G, B) tuples
        return width, height, pixel_data
    except FileNotFoundError:
        print(f"Error: The file {jpeg_filepath} was not found.")
        return None, None, None
    except Exception as e:
        print(f"An error occurred while reading JPEG: {e}")
        return None, None, None

def generate_output_trace(jpeg_filepath, output_trace_filepath):
    """
    Generates the expected output trace file for the JPEG decoder.
    """
    image_width, image_height, rgb_pixels = get_rgb_from_jpeg(jpeg_filepath)

    if not rgb_pixels:
        return

    print(f"Successfully decoded {jpeg_filepath}: {image_width}x{image_height}, {len(rgb_pixels)} pixels.")

    with open(output_trace_filepath, 'w') as f:
        f.write(f"# Expected RGB Output Trace File for {jpeg_filepath}\n")
        f.write(f"# Image Dimensions: {image_width}x{image_height}\n")
        f.write("# Format: 0010____<88_bit_packed_data>\n")
        f.write("# 88-bit data: out_width(16)out_height(16)pixel_x(16)pixel_y(16)R(8)G(8)B(8)\n\n")

        # Format image width and height once as they are constant for all pixels
        w_bin = format(image_width, '016b')
        h_bin = format(image_height, '016b')

        pixel_index = 0
        for y in range(image_height):
            for x in range(image_width):
                if pixel_index < len(rgb_pixels):
                    r, g, b = rgb_pixels[pixel_index]

                    # Format pixel coordinates and RGB values
                    px_bin = format(x, '016b')
                    py_bin = format(y, '016b')
                    r_bin = format(r, '08b')
                    g_bin = format(g, '08b')
                    b_bin = format(b, '08b')

                    # Concatenate all parts to form the 88-bit data payload
                    # Order: width, height, pixel_x, pixel_y, R, G, B
                    data_88bit = w_bin + h_bin + px_bin + py_bin + r_bin + g_bin + b_bin
                    
                    if len(data_88bit) != 88:
                        # This should not happen if formatting is correct
                        print(f"Error: Generated data is not 88 bits long for pixel ({x},{y})!")
                        print(f"Data: {data_88bit}")
                        continue

                    # Write the trace line with the "receive & check" opcode
                    # f.write(f"0010____{data_88bit}\n")
                    f.write(data_88bit + "\n")
                    pixel_index += 1
                else:
                    # Should not happen if Pillow provides all pixels
                    print(f"Warning: Ran out of pixel data at ({x},{y}).")
                    break
            if pixel_index >= len(rgb_pixels) and y < image_height -1 : # break outer loop if pixels end early
                 print(f"Warning: Pixel data ended prematurely after row {y}.")
                 break


        # Add some wait cycles for stability before finishing (optional, but good practice)
        # Using 88 zeros for the payload of wait commands, matching ring width
        wait_payload_88bit = '0' * 88
        f.write("\n# Wait a few cycles (Opcode 0000)\n")
        for _ in range(5): # Example: 5 wait cycles
            f.write(f"0000____{wait_payload_88bit}\n")

        # Add a "finish simulation" command (Opcode 0100)
        # Payload for 0100 can also be 88 zeros.
        finish_payload_88bit = '0' * 88
        f.write("\n# Finish simulation (Opcode 0100)\n")
        f.write(f"0100____{finish_payload_88bit}\n")
        
        print(f"Generated expected RGB output trace: {output_trace_filepath}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate expected RGB output traces for a JPEG decoder.')
    parser.add_argument('--input_jpeg', '-i', required=True, help='Path to the input JPEG file (e.g., cat.jpg)')
    parser.add_argument('--output_trace', '-o', required=True, help='Path for the generated output trace file (e.g., trace_output_rgb.tr)')
    
    args = parser.parse_args()
    
    generate_output_trace(args.input_jpeg, args.output_trace)

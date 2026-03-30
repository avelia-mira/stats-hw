import os
from pypdf import PdfReader, PdfWriter

def clean_pdf(input_path, output_path):
    reader = PdfReader(input_path)
    writer = PdfWriter()
    
    pages = reader.pages
    num_pages = len(pages)
    
    print(f"Processing: {input_path} ({num_pages} pages)")
    
    # Iterate through all pages except the last one
    for i in range(num_pages - 1):
        current_page = pages[i]
        next_page = pages[i+1]
        
        # Extract text and strip whitespace for comparison
        # We assume if the current page text is fully inside the next page, 
        # it is a transition/build slide.
        curr_text = current_page.extract_text().replace(" ", "").replace("\n", "")
        next_text = next_page.extract_text().replace(" ", "").replace("\n", "")
        
        # If the current page text is NOT in the next page, keep it.
        # This means the next page is likely a NEW slide, or the current page
        # has content (like a page number) that makes it distinct.
        if curr_text not in next_text:
            writer.add_page(current_page)
            
    # Always add the very last page of the PDF
    writer.add_page(pages[-1])
    
    # Save the new PDF
    with open(output_path, "wb") as f:
        writer.write(f)
    print(f"--> Saved cleaned version to: {output_path}")

def main():
    # Get current working directory
    cwd = os.getcwd()
    
    # Create cleaned_slides folder if it doesn't exist
    cleaned_folder = os.path.join(cwd, "cleaned_slides")
    if not os.path.exists(cleaned_folder):
        os.makedirs(cleaned_folder)
        print(f"Created folder: {cleaned_folder}")
    
    # List all files in directory
    for filename in os.listdir(cwd):
        # Check for PDF extension and ensure we aren't re-processing a cleaned file
        if filename.lower().endswith(".pdf") and "_cleaned" not in filename and "slides" in filename.lower():
            
            output_filename = f"{os.path.splitext(filename)[0]}_cleaned.pdf"
            output_path = os.path.join(cleaned_folder, output_filename)
            
            # CHECK: If the output file already exists, skip it
            if os.path.exists(output_path):
                print(f"Skipping {filename} (Cleaned version already exists in cleaned_slides/).")
                continue
            
            try:
                clean_pdf(filename, output_path)
            except Exception as e:
                print(f"Failed to process {filename}: {e}")

if __name__ == "__main__":
    main()
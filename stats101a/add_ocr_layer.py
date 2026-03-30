#!/usr/bin/env python3
"""
Add proper OCR text layer to extracted PDFs for highlighting support.
Uses ocrmypdf which positions text correctly for selection/highlighting.
"""

import subprocess
from pathlib import Path
import shutil
from tqdm import tqdm

def add_ocr_layer(input_dir):
    """Add OCR layer to all extracted PDFs."""
    input_dir = Path(input_dir)
    
    # Find all extracted PDFs
    pdf_files = sorted(input_dir.glob("lecture - * extracted.pdf"))
    
    if not pdf_files:
        print("✗ No extracted PDFs found")
        return
    
    print(f"✓ Found {len(pdf_files)} extracted PDFs\n")
    
    for pdf_path in tqdm(pdf_files, desc="Adding OCR layers"):
        # Create temporary output path
        temp_output = pdf_path.with_suffix('.tmp.pdf')
        
        try:
            # Run ocrmypdf with fast settings
            # --force-ocr: OCR even if text is present (redo OCR)
            # --optimize 0: No optimization for speed
            # --jobs 4: Use 4 cores for parallel processing
            # --quiet: Minimal output
            result = subprocess.run([
                'ocrmypdf',
                '--force-ocr',
                '--optimize', '0',
                '--jobs', '4',  
                '--quiet',
                str(pdf_path),
                str(temp_output)
            ], capture_output=True, text=True, timeout=600)
            
            if result.returncode == 0:
                # Replace original with OCR version
                shutil.move(temp_output, pdf_path)
            else:
                print(f"\n  ⚠ OCR failed for {pdf_path.name}: {result.stderr}")
                if temp_output.exists():
                    temp_output.unlink()
                    
        except subprocess.TimeoutExpired:
            print(f"\n  ⚠ Timeout for {pdf_path.name}")
            if temp_output.exists():
                temp_output.unlink()
        except Exception as e:
            print(f"\n  ⚠ Error for {pdf_path.name}: {e}")
            if temp_output.exists():
                temp_output.unlink()
    
    print("\n✓ OCR processing complete")


if __name__ == "__main__":
    input_dir = "/Users/mariaannalissasantos/Downloads/stats/stats101a/lectures"
    add_ocr_layer(input_dir)

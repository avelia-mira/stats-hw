#!/usr/bin/env python3
"""
Script to split PDF slides by detected rectangles and apply OCR.
Handles PDFs with multiple content areas per page and converts them to individual slides.
Combines all slides into a single output PDF with page sizes matching the rectangles.
"""

import os
import sys
from pathlib import Path
from pdf2image import convert_from_path
import cv2
import numpy as np
from PIL import Image
import pytesseract
import fitz  # PyMuPDF
from tqdm import tqdm
import shutil

class PDFSliceSplitter:
    def __init__(self, input_dir, output_dir, min_rectangle_area=50000):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.min_rectangle_area = min_rectangle_area
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def detect_rectangles(self, image_cv):
        """Detect rectangular regions in image using contour detection."""
        # Convert to grayscale
        if len(image_cv.shape) == 3:
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
        else:
            gray = image_cv
            
        # Apply threshold
        _, thresh = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
        
        # Find contours
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        rectangles = []
        for contour in contours:
            x, y, w, h = cv2.boundingRect(contour)
            area = w * h
            
            # Filter by minimum area and aspect ratio (to avoid noise)
            if area > self.min_rectangle_area and 0.3 < (w/h if h > 0 else 0) < 3.3:
                rectangles.append((x, y, w, h))
        
        # Sort by position (top to bottom, left to right)
        rectangles.sort(key=lambda r: (r[1], r[0]))
        
        return rectangles
    
    def merge_overlapping_rects(self, rects, overlap_threshold=0.3):
        """Merge overlapping or nearby rectangles."""
        if not rects:
            return []
        
        merged = []
        used = set()
        
        for i, (x1, y1, w1, h1) in enumerate(rects):
            if i in used:
                continue
            
            # Start with current rectangle
            min_x, min_y = x1, y1
            max_x, max_y = x1 + w1, y1 + h1
            
            # Merge with overlapping rectangles
            for j, (x2, y2, w2, h2) in enumerate(rects[i+1:], start=i+1):
                if j in used:
                    continue
                
                # Check for overlap
                if not (max_x < x2 or min_x > x2 + w2 or max_y < y2 or min_y > y2 + h2):
                    used.add(j)
                    min_x = min(min_x, x2)
                    min_y = min(min_y, y2)
                    max_x = max(max_x, x2 + w2)
                    max_y = max(max_y, y2 + h2)
            
            merged.append((min_x, min_y, max_x - min_x, max_y - min_y))
            used.add(i)
        
        return merged
    
    def crop_and_ocr(self, image_cv, rect):
        """Crop rectangle from image and apply OCR."""
        x, y, w, h = rect
        # Add small padding
        padding = 10
        x = max(0, x - padding)
        y = max(0, y - padding)
        w = min(image_cv.shape[1] - x, w + 2*padding)
        h = min(image_cv.shape[0] - y, h + 2*padding)
        
        cropped = image_cv[y:y+h, x:x+w]
        
        # Apply OCR
        try:
            text = pytesseract.image_to_string(cropped)
            return cropped, text
        except Exception as e:
            print(f"OCR failed: {e}")
            return cropped, ""
    
    def save_slide(self, image_cv, text, slide_num):
        """Save slide image and return it for later PDF creation."""
        # Convert to PIL
        image_pil = Image.fromarray(cv2.cvtColor(image_cv, cv2.COLOR_BGR2RGB))
        return image_pil, text
    
    def process_pdf(self, pdf_path):
        """Process a single PDF file and collect slides."""
        print(f"\nProcessing: {pdf_path.name}")
        
        slides = []  # List to store (image_pil, text) tuples
        
        try:
            # Convert PDF to images
            print("  Converting PDF to images...")
            images = convert_from_path(str(pdf_path), dpi=150)
            
            for page_num, image_pil in enumerate(tqdm(images, desc="  Processing pages"), 1):
                # Convert to OpenCV format
                image_cv = cv2.cvtColor(np.array(image_pil), cv2.COLOR_RGB2BGR)
                
                # Detect rectangles
                rects = self.detect_rectangles(image_cv)
                
                if not rects:
                    # No rectangles detected, save whole page
                    print(f"    Page {page_num}: No rectangles detected, saving whole page")
                    image_pil_out = Image.fromarray(cv2.cvtColor(image_cv, cv2.COLOR_BGR2RGB))
                    slides.append((image_pil_out, ""))
                else:
                    # Merge overlapping rectangles
                    rects = self.merge_overlapping_rects(rects)
                    
                    print(f"    Page {page_num}: Found {len(rects)} content areas")
                    
                    # Crop and save each rectangle
                    for rect_num, rect in enumerate(rects, 1):
                        cropped, text = self.crop_and_ocr(image_cv, rect)
                        image_pil_out, text = self.save_slide(cropped, text, len(slides) + 1)
                        slides.append((image_pil_out, text))
            
            return slides
            
        except Exception as e:
            print(f"  ✗ Error processing {pdf_path.name}: {e}")
            import traceback
            traceback.print_exc()
            return []
    
    def create_combined_pdf(self, all_slides, output_pdf_path):
        """Create a single combined PDF with all slides, each with its own page size."""
        print(f"\nCreating combined PDF: {output_pdf_path.name}")
        
        # Create a new PDF document
        doc = fitz.open()
        
        for slide_num, (image_pil, text) in enumerate(tqdm(all_slides, desc="  Adding slides to PDF"), 1):
            # Get image dimensions
            width, height = image_pil.size
            
            # Create a new page with dimensions matching the image
            page_rect = fitz.Rect(0, 0, width, height)
            page = doc.new_page(rect=page_rect)
            
            # Convert PIL image to bytes
            img_bytes = image_pil.tobytes("ppm")
            pixmap = fitz.Pixmap(fitz.csRGB, width, height, img_bytes, alpha=False)
            
            # Insert image into page (fill entire page)
            page.insert_image(page.rect, pixmap=pixmap)
            
            # Add OCR text as invisible layer for searchability (if available)
            if text.strip():
                text_snippet = text[:200] if len(text) > 200 else text
                # Insert text with very small font at bottom corner (essentially invisible)
                page.insert_text((5, height - 10), text_snippet, fontsize=1, color=(1, 1, 1))
        
        # Save the combined PDF
        doc.save(str(output_pdf_path))
        doc.close()
        
        print(f"  ✓ Combined PDF saved: {output_pdf_path}")
        print(f"    Total pages: {len(all_slides)}")
    
    def run(self):
        """Process all PDFs in the input directory and combine into one."""
        # Only get PDFs that match the lecture format (lecture - x.x.pdf)
        pdf_files = sorted([f for f in self.input_dir.glob("*.pdf") if f.name.startswith("lecture - ") and f.name.count('.') == 2])
        
        if not pdf_files:
            print(f"No PDF files found in {self.input_dir}")
            return
        
        print(f"Found {len(pdf_files)} PDF files")
        print(f"Output directory: {self.output_dir}")
        
        all_slides = []
        
        for pdf_path in pdf_files:
            slides = self.process_pdf(pdf_path)
            all_slides.extend(slides)
        
        # Create combined PDF
        output_pdf = self.output_dir / "all_lectures_combined.pdf"
        self.create_combined_pdf(all_slides, output_pdf)
        
        print("\n✓ All PDFs processed and combined!")
        print(f"Output saved to: {output_pdf}")


def main():
    input_dir = "/Users/mariaannalissasantos/Downloads/stats/stats101a/lectures"
    output_dir = "/Users/mariaannalissasantos/Downloads/stats/stats101a/lecture_slides"
    
    # Check if required tools are installed
    try:
        import pytesseract
        pytesseract.get_tesseract_version()
    except Exception as e:
        print("Error: Tesseract OCR not installed.")
        print("Install with: brew install tesseract")
        return
    
    splitter = PDFSliceSplitter(input_dir, output_dir)
    splitter.run()


if __name__ == "__main__":
    main()

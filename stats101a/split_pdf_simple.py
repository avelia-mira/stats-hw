#!/usr/bin/env python3
"""
PDF slide splitter - crops rectangles and makes each one a full page slide.
Each rectangle becomes its own page with no whitespace outside the content.
"""

import os
from pathlib import Path
from pdf2image import convert_from_path
import cv2
import numpy as np
from PIL import Image
import fitz  # PyMuPDF
from tqdm import tqdm
import tempfile


class RectangleCropSplitter:
    def __init__(self, input_dir, output_pdf):
        self.input_dir = Path(input_dir)
        self.output_pdf = Path(output_pdf)
        self.min_rectangle_area = 100000  # Increased to avoid tiny noise rectangles
        
    def detect_rectangles(self, image_cv):
        """Detect rectangular content areas - much more aggressive detection."""
        if len(image_cv.shape) == 3:
            gray = cv2.cvtColor(image_cv, cv2.COLOR_BGR2GRAY)
        else:
            gray = image_cv
        
        # Use Canny edge detection for better rectangle detection
        edges = cv2.Canny(gray, 50, 150)
        
        # Dilate to connect nearby edges
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        dilated = cv2.dilate(edges, kernel, iterations=2)
        
        # Find contours
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        rectangles = []
        for contour in contours:
            # Approximate contour to polygon
            epsilon = 0.02 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)
            
            # Check if approximately rectangular (4 corners)
            if len(approx) == 4:
                x, y, w, h = cv2.boundingRect(approx)
                area = w * h
                aspect = w / h if h > 0 else 0
                
                # Filter by minimum area and aspect ratio (not too extreme)
                if area > self.min_rectangle_area and 0.2 < aspect < 5.0:
                    rectangles.append((x, y, w, h))
        
        # Sort by position (top to bottom, left to right)
        rectangles.sort(key=lambda r: (r[1], r[0]))
        
        return rectangles
    
    def remove_duplicate_rects(self, rects, tolerance=20):
        """Remove near-duplicate rectangles (same location)."""
        if not rects:
            return []
        
        unique = []
        for rect in rects:
            x, y, w, h = rect
            is_duplicate = False
            
            for ux, uy, uw, uh in unique:
                # Check if rectangles are very close (likely duplicates)
                if abs(x - ux) < tolerance and abs(y - uy) < tolerance:
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                unique.append(rect)
        
        return unique
    
    def crop_rectangle(self, image_cv, rect):
        """Crop rectangle from image with minimal padding."""
        x, y, w, h = rect
        
        # Add very small padding (just 1-2 pixels)
        padding = 1
        x = max(0, x - padding)
        y = max(0, y - padding)
        x_end = min(image_cv.shape[1], x + w + 2*padding)
        y_end = min(image_cv.shape[0], y + h + 2*padding)
        
        cropped = image_cv[y:y_end, x:x_end]
        return cropped
    
    def process_pdfs(self):
        """Process all lecture PDFs and collect cropped slides."""
        # Only process files matching "lecture - x.x.pdf" pattern
        pdf_files = sorted([f for f in self.input_dir.glob("*.pdf") 
                           if f.name.startswith("lecture - ") and f.name.endswith(".pdf")])
        
        if not pdf_files:
            print(f"❌ No lecture PDFs found in {self.input_dir}")
            return []
        
        print(f"✓ Found {len(pdf_files)} lecture PDFs\n")
        
        all_slides = []
        
        for pdf_path in pdf_files:
            print(f"Processing: {pdf_path.name}")
            
            try:
                images = convert_from_path(str(pdf_path), dpi=150)
                
                for page_num, image_pil in enumerate(tqdm(images, desc="  Pages"), 1):
                    image_cv = cv2.cvtColor(np.array(image_pil), cv2.COLOR_RGB2BGR)
                    
                    # Detect rectangles
                    rects = self.detect_rectangles(image_cv)
                    rects = self.remove_duplicate_rects(rects)
                    
                    if not rects:
                        # No rectangles detected, save whole page as-is
                        all_slides.append(image_pil)
                    else:
                        # Crop and save each rectangle as its own slide
                        for rect_idx, rect in enumerate(rects):
                            cropped_cv = self.crop_rectangle(image_cv, rect)
                            # Convert back to PIL
                            slide_pil = Image.fromarray(cv2.cvtColor(cropped_cv, cv2.COLOR_BGR2RGB))
                            all_slides.append(slide_pil)
                
                print(f"  ✓ Extracted {len(all_slides)} slides total\n")
                
            except Exception as e:
                print(f"  ❌ Error: {e}\n")
        
        return all_slides
    
    def create_combined_pdf(self, slides):
        """Create combined PDF where each slide is its own full page."""
        if not slides:
            print("❌ No slides to combine!")
            return
        
        print(f"\nCreating combined PDF with {len(slides)} slides...")
        doc = fitz.open()
        
        # Use temporary directory for image files
        with tempfile.TemporaryDirectory() as tmpdir:
            for idx, slide_pil in enumerate(tqdm(slides, desc="Adding slides")):
                width, height = slide_pil.size
                
                # Create new page with exact slide dimensions
                page = doc.new_page(width=width, height=height)
                
                # Save slide to temp file
                temp_img = os.path.join(tmpdir, f"slide_{idx:05d}.png")
                slide_pil.save(temp_img)
                
                # Insert image as full page (no scaling, exact size)
                page.insert_image(page.rect, filename=temp_img)
        
        doc.save(str(self.output_pdf))
        doc.close()
        
        print(f"\n✓ Saved {len(slides)} slides to: {self.output_pdf}")
    
    def run(self):
        """Run the splitter."""
        slides = self.process_pdfs()
        if slides:
            self.create_combined_pdf(slides)


if __name__ == "__main__":
    input_dir = "/Users/mariaannalissasantos/Downloads/stats/stats101a/lectures"
    output_pdf = "/Users/mariaannalissasantos/Downloads/stats/stats101a/lectures/all_lectures_combined.pdf"
    
    splitter = RectangleCropSplitter(input_dir, output_pdf)
    splitter.run()

#!/usr/bin/env python3
"""
PDF slide splitter with upscaling (fast version).
- Crops rectangles from each lecture PDF
- Upscales slides for better quality using LANCZOS4
- Creates separate output PDF per lecture
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
import shutil
import re


class RectangleCropUpscale:
    def __init__(self, input_dir, upscale_factor=2.0):
        self.input_dir = Path(input_dir)
        self.upscale_factor = upscale_factor
        self.temp_dir = tempfile.mkdtemp()
        
    def detect_rectangles(self, cv_image):
        """Detect rectangular slide areas using Canny edge detection."""
        gray = cv2.cvtColor(cv_image, cv2.COLOR_RGB2GRAY)
        
        # Apply Canny edge detection
        edges = cv2.Canny(gray, 50, 150)
        
        # Dilate to connect edges
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        dilated = cv2.dilate(edges, kernel, iterations=2)
        
        # Find contours
        contours, _ = cv2.findContours(dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        rectangles = []
        min_rectangle_area = 100000
        
        for contour in contours:
            epsilon = 0.02 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)
            
            # Check if it's a rectangle (4 points)
            if len(approx) == 4:
                area = cv2.contourArea(contour)
                if area > min_rectangle_area:
                    x, y, w, h = cv2.boundingRect(approx)
                    aspect_ratio = w / h if h > 0 else 0
                    
                    # Flexible aspect ratio filter
                    if 0.2 <= aspect_ratio <= 5.0:
                        rectangles.append((x, y, w, h))
        
        return self.remove_duplicate_rects(rectangles)
    
    def remove_duplicate_rects(self, rectangles):
        """Remove near-duplicate rectangles."""
        if not rectangles:
            return []
        
        # Sort by area (largest first)
        rectangles = sorted(rectangles, key=lambda r: r[2] * r[3], reverse=True)
        
        unique_rects = []
        tolerance = 20
        
        for rect in rectangles:
            is_duplicate = False
            for existing in unique_rects:
                if (abs(rect[0] - existing[0]) < tolerance and
                    abs(rect[1] - existing[1]) < tolerance and
                    abs(rect[2] - existing[2]) < tolerance and
                    abs(rect[3] - existing[3]) < tolerance):
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                unique_rects.append(rect)
        
        return unique_rects
    
    def upscale_image(self, image):
        """Upscale image using high-quality LANCZOS4 interpolation."""
        h, w = image.shape[:2]
        new_h = int(h * self.upscale_factor)
        new_w = int(w * self.upscale_factor)
        
        # LANCZOS4 provides excellent quality
        upscaled = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_LANCZOS4)
        return upscaled
    
    def crop_rectangle(self, image, rect):
        """Crop a rectangle from image with minimal padding."""
        x, y, w, h = rect
        padding = 1
        
        x1 = max(0, x - padding)
        y1 = max(0, y - padding)
        x2 = min(image.shape[1], x + w + padding)
        y2 = min(image.shape[0], y + h + padding)
        
        return image[y1:y2, x1:x2]
    
    def process_pdf(self, pdf_path):
        """Process a single PDF and extract upscaled slides."""
        slides = []
        
        # Convert PDF to images at 150 DPI
        images = convert_from_path(pdf_path, dpi=150)
        
        for page_idx, pil_image in enumerate(tqdm(images, desc=f"  Pages")):
            # Convert PIL to OpenCV format
            cv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
            
            # Detect rectangles
            rectangles = self.detect_rectangles(cv_image)
            
            # Crop and upscale each rectangle
            for rect_idx, rect in enumerate(rectangles):
                cropped = self.crop_rectangle(cv_image, rect)
                
                # Upscale for better quality
                upscaled = self.upscale_image(cropped)
                
                slides.append({
                    'image': upscaled,
                    'page': page_idx,
                    'rect_idx': rect_idx
                })
        
        return slides
    
    def create_pdf(self, slides, output_path):
        """Create PDF from upscaled slides."""
        if not slides:
            return
        
        doc = fitz.open()
        
        for slide_data in tqdm(slides, desc="Adding slides"):
            image_array = slide_data['image']
            
            # Save image to temporary PNG
            temp_png = os.path.join(self.temp_dir, f"temp_{len(doc)}.png")
            cv2.imwrite(temp_png, image_array)
            
            # Get image dimensions
            h, w = image_array.shape[:2]
            
            # Create new page with exact image dimensions
            # At 150 DPI: 1 pixel = 72/150 points
            page_width = w * 72 / 150
            page_height = h * 72 / 150
            
            page = doc.new_page(width=page_width, height=page_height)
            
            # Insert image to fill entire page
            rect = fitz.Rect(0, 0, page_width, page_height)
            page.insert_image(rect, filename=temp_png)
        
        doc.save(output_path)
        doc.close()
        print(f"  ✓ Saved {len(slides)} slides to: {output_path}")
    
    def process_all_pdfs(self):
        """Process all lecture PDFs in input directory."""
        pdf_files = sorted(self.input_dir.glob("lecture - *.pdf"))
        
        # Filter out already extracted files
        pdf_files = [f for f in pdf_files if "extracted" not in f.name]
        
        if not pdf_files:
            print("✗ No lecture PDFs found")
            return
        
        print(f"✓ Found {len(pdf_files)} lecture PDFs\n")
        
        for pdf_path in pdf_files:
            # Extract lecture name (e.g., "1.1" from "lecture - 1.1.pdf")
            match = re.search(r'lecture - ([0-9.]+[a-z]?)\s*\.pdf', pdf_path.name, re.IGNORECASE)
            if not match:
                continue
            
            lecture_num = match.group(1)
            output_path = self.input_dir / f"lecture - {lecture_num} extracted.pdf"
            
            print(f"Processing: {pdf_path.name}")
            
            # Process PDF
            slides = self.process_pdf(pdf_path)
            
            if slides:
                print(f"  ✓ Extracted {len(slides)} slides")
                
                # Create output PDF
                self.create_pdf(slides, output_path)
            else:
                print(f"  ✗ No slides extracted")
            
            print()
        
        # Cleanup
        shutil.rmtree(self.temp_dir)
        print("✓ Processing complete")
    
    def run(self):
        """Run the processor."""
        self.process_all_pdfs()


if __name__ == "__main__":
    input_dir = "/Users/mariaannalissasantos/Downloads/stats/stats101a/lectures"
    
    processor = RectangleCropUpscale(
        input_dir=input_dir,
        upscale_factor=2.0  # 2x upscaling for better quality
    )
    processor.run()

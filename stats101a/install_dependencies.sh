#!/bin/bash

echo "Installing dependencies for PDF slide splitter..."

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    exit 1
fi

echo "Installing Python packages..."
python3 -m pip install --upgrade pip
python3 -m pip install pdf2image opencv-python pytesseract pillow reportlab PyMuPDF tqdm

echo ""
echo "Installing Tesseract OCR (required for OCR functionality)..."

# Check OS and install accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
        echo "Using Homebrew to install tesseract..."
        brew install tesseract
    else
        echo "Error: Homebrew not found. Please install it or install Tesseract manually."
        echo "Visit: https://github.com/UB-Mannheim/tesseract/wiki"
        exit 1
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Using apt to install tesseract..."
    sudo apt-get update
    sudo apt-get install -y tesseract-ocr
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows
    echo "For Windows, please download and install Tesseract from:"
    echo "https://github.com/UB-Mannheim/tesseract/wiki/Downloads"
    exit 1
fi

echo ""
echo "✓ All dependencies installed!"
echo ""
echo "To run the script:"
echo "  python3 split_pdf_slides.py"
echo ""

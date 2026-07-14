import os
import uuid
import shutil
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, UploadFile, File, status
from fastapi.responses import JSONResponse, FileResponse
from pathlib import Path

router = APIRouter(prefix="/upload")

# Create uploads directory if it doesn't exist
UPLOAD_DIR = Path("uploads/pdfs")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/pdf")
async def upload_pdf(file: UploadFile = File(...)):
    """Upload a PDF file and return its URL"""
    
    print(f"Received file: {file.filename}")
    
    if not file.filename.endswith('.pdf'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF files are allowed"
        )
    
    # Generate unique filename
    unique_id = uuid.uuid4().hex[:8]
    safe_filename = f"{unique_id}.pdf"
    file_path = UPLOAD_DIR / safe_filename
    
    try:
        content = await file.read()
        print(f"File size: {len(content)} bytes")
        
        with open(file_path, "wb") as buffer:
            buffer.write(content)
        
        print(f"File saved to: {file_path}")
        
        # Return the URL
        file_url = f"/uploads/pdfs/{safe_filename}"
        
        return {
            "status": "ok",
            "url": file_url,
            "filename": safe_filename,
            "size": len(content)
        }
    except Exception as e:
        print(f"Error uploading file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload file: {str(e)}"
        )
    finally:
        await file.close()


@router.get("/pdf/{filename}")
async def get_pdf(filename: str):
    file_path = UPLOAD_DIR / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(
        path=file_path, 
        media_type="application/pdf", 
        filename=filename
    )
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import httpx

router = APIRouter()

GEMINI_API_KEY = "your_gemini_api_key_here"  # Replace with your actual API key

class ChatRequest(BaseModel):
    message: str
    context: dict

@router.post("/ai/chat")
async def ai_chat(payload: ChatRequest):

    # Summarize data instead of sending full JSON
    courses_summary = []
    for c in payload.context.get('courses', []):
        classes_info = []
        for cls in c.get('classes', []):
            classes_info.append(
                f"    classId={cls.get('classId', '')} day={cls.get('day', '')} room={cls.get('room', '')}"
            )
        classes_str = '\n'.join(classes_info) if classes_info else '    no classes'
        courses_summary.append(
            f"courseId={c.get('courseId', '')} title={c.get('title', '')}\n{classes_str}"
        )

    missing_sub_summary = []
    for m in payload.context.get('missingSubmissions', [])[:]:
        names = [s.get('name', '') for s in m.get('missingStudents', [])[:]]
        missing_sub_summary.append(f"- {m.get('title', '')} in {m.get('courseName', '')}: {', '.join(names)}")

    missing_grades_summary = []
    for g in payload.context.get('missingGrades', [])[:5]:
        missing_grades_summary.append(f"- {g.get('name', '')} in {g.get('courseName', '')}")

    absence_summary = []
    for a in payload.context.get('absenceWarnings', [])[:5]:
        absence_summary.append(f"- {a.get('name', '')} ({a.get('absent', 0)} absences) in {a.get('courseName', '')}")

    prompt = f"""You are an AI assistant for a university professor.
    IMPORTANT: Do not use any emojis in your response. Use plain text and bullet points only.

COURSES (use exact IDs):
{chr(10).join(courses_summary) or 'None'}

MISSING SUBMISSIONS:
{chr(10).join(missing_sub_summary) or 'None'}

MISSING GRADES:
{chr(10).join(missing_grades_summary) or 'None'}

STUDENTS WITH 7+ ABSENCES:
{chr(10).join(absence_summary) or 'None'}

RULES:
- Be concise, use bullet points only, no emojis
- To send announcements use this EXACT format, ONE LINE PER COURSE/CLASS (never truncate):
  SEND_ANNOUNCEMENT|courseId|classId|title|message
- If the request targets multiple courses or classes, output ONE SEND_ANNOUNCEMENT line for EACH
- Use the EXACT courseId and classId from the COURSES section above
- Keep entire response under 200 words

Question: {payload.message}"""

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}",
            headers={"Content-Type": "application/json"},
            json={
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.7, "maxOutputTokens": 2000},
            },
            timeout=30,
        )
        data = response.json()
        print("Gemini response:", data)

        if "candidates" not in data:
            error_msg = data.get("error", {}).get("message", "Unknown error")
            raise HTTPException(status_code=500, detail=f"Gemini error: {error_msg}")

        text = data["candidates"][0]["content"]["parts"][0]["text"]
        return {"response": text}


@router.get("/ai/models")
async def list_models():
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://generativelanguage.googleapis.com/v1beta/models?key={GEMINI_API_KEY}",
        )
        return response.json()
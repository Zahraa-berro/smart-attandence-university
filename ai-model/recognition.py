import face_recognition
import numpy as np
import pickle
import cv2

with open("encodings.pkl", "rb") as file:
    data = pickle.load(file)

known_encodings = data["encodings"]
known_ids = data["ids"]

def predict_student(frame):

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    face_locations = face_recognition.face_locations(rgb)

    face_encodings = face_recognition.face_encodings(
        rgb,
        face_locations
    )

    if len(face_encodings) == 0:

        return {
            "student_id": "no_face",
            "confidence": 0.0,
            "face_detected": False
        }

    for face_encoding in face_encodings:

        matches = face_recognition.compare_faces(
            known_encodings,
            face_encoding
        )

        distances = face_recognition.face_distance(
            known_encodings,
            face_encoding
        )

        best_match_index = np.argmin(distances)

        confidence = 1 - distances[best_match_index]

        if matches[best_match_index] and confidence > 0.85:

            return {
                "student_id": known_ids[best_match_index],
                "confidence": float(confidence),
                "face_detected": True
            }

        else:

            return {
                "student_id": "unknown",
                "confidence": float(confidence),
                "face_detected": True
            }
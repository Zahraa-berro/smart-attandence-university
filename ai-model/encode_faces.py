import face_recognition
import os
import pickle

dataset_path = "dataset"

known_encodings = []
known_ids = []

for student_id in os.listdir(dataset_path):

    student_folder = os.path.join(dataset_path, student_id)

    for image_name in os.listdir(student_folder):

        image_path = os.path.join(student_folder, image_name)

        image = face_recognition.load_image_file(image_path)

        encodings = face_recognition.face_encodings(image)

        if len(encodings) > 0:

            known_encodings.append(encodings[0])
            known_ids.append(student_id)

data = {
    "encodings": known_encodings,
    "ids": known_ids
}

with open("encodings.pkl", "wb") as file:
    pickle.dump(data, file)

print("Face encodings saved successfully")
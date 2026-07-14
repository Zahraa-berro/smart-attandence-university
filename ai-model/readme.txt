- the data in the mongo db should be stored like the dataset , so each student has a folder for around 2 or 3 image , the folder should named by the id
- the ids should starts from 202610000 and then auto increments
- the code need to be changed --> encode_faces file : instead of fetching images from the dataset they should be fetched by the backend from data base and then encoded
- when new student is added , the encodings.pkl file should be appended not deleted and rebuild
- examples of ai result :
{
    "confidence": 0.2735507787876251,
    "face_detected": true,
    "student_id": "unknown"
}
or
{
    "confidence": 0.94,
    "face_detected": true,
    "student_id": "202610031"
}

from flask import Flask, request, jsonify
import numpy as np
import cv2

from recognition import predict_student

app = Flask(__name__)

@app.route("/predict", methods=["POST"])
def predict():

    if "image" not in request.files:

        return jsonify({
            "error": "No image uploaded"
        })

    file = request.files["image"]

    npimg = np.frombuffer(
        file.read(),
        np.uint8
    )

    frame = cv2.imdecode(
        npimg,
        cv2.IMREAD_COLOR
    )

    result = predict_student(frame)

    return jsonify(result)

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )
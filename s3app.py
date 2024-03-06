import os
from flask import Flask, render_template, request, redirect, send_file
from s3_functions import upload_file
from werkzeug.utils import secure_filename
import boto3


app = Flask(__name__)
UPLOAD_FOLDER = "uploads"
BUCKET = "dw-bucket54321"

#if __name__ == '__main__':
#    app.run(host="0.0.0.0", port=4000, debug=True)

def upload_file(file_name, bucket):
    object_name = file_name
    s3_client = boto3.client('s3')
    response = s3_client.upload_file(file_name, bucket, object_name)
    return response

@app.route("/")
def home():
    return render_template('index.html')

@app.route("/upload", methods=['POST'])
def upload():
    if request.method == "POST":
        f = request.files['file']
        f.save(os.path.join(UPLOAD_FOLDER, secure_filename(f.filename)))
        upload_file(f"uploads/{f.filename}", BUCKET)
        return redirect("/")

app.run(host="0.0.0.0", port=4000, debug=True)
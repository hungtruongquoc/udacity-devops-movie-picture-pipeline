import os
from flask import Flask
from flask_cors import CORS

from .movies import movies_api

app = Flask(__name__)
# More explicit CORS configuration
CORS(app, resources={
    r"/*": {
        "origins": "*",  # In production, you might want to restrict this
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})
app.register_blueprint(movies_api)

# Start app
if __name__ == "__main__":
    app.run(
        debug=True,
        host="0.0.0.0",
        port=int(os.getenv("FLASK_RUN_PORT", 5000)),
    )

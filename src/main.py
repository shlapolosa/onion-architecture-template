"""Main application entry point following 12-factor principles"""
import uvicorn
from interface.api import app
from infrastructure.config import load_settings

if __name__ == "__main__":
    # 12-Factor: Port binding — config via the single Settings source
    uvicorn.run(app, host="0.0.0.0", port=load_settings().port)

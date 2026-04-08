#!/usr/bin/env bash
# Run the FastAPI backend. Use this if 'uvicorn' is not on your PATH.
cd "$(dirname "$0")"
python3 -m uvicorn main:app --reload

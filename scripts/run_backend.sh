#!/usr/bin/env bash
# Start VeriBite FastAPI Backend on 0.0.0.0:8000
# Binding to 0.0.0.0 allows physical Android devices on the same Wi-Fi/hotspot to connect via LAN IP
echo "=========================================================="
echo "Starting VeriBite FastAPI Backend Proxy on 0.0.0.0:8000"
echo "Local loopback: http://127.0.0.1:8000"
echo "Android Emulator: http://10.0.2.2:8000"
echo "Physical Phone (USB reverse): run 'adb reverse tcp:8000 tcp:8000'"
echo "=========================================================="

python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload

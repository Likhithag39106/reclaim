# AI Microservice Deployment Guide

Complete instructions for deploying the AI Recovery Plan microservice.

## 🎯 Overview

This guide covers:
- ✅ Environment setup (Python 3.10)
- ✅ AI service deployment (FastAPI + TensorFlow)
- ✅ Integration with Python 3.14 main app
- ✅ Testing and verification
- ✅ Production deployment

---

## 📋 Prerequisites

### Required Software
- **Python 3.10** (for AI service) - [Download here](https://www.python.org/downloads/release/python-3100/)
- **Python 3.14** (for main app) - Already installed
- **Git** (for version control)
- **curl** or **Postman** (for testing)

### System Requirements
- **RAM**: 2GB minimum (4GB recommended)
- **Disk**: 500MB for dependencies
- **Network**: Port 8000 available for AI service

---

## 🚀 Step 1: Environment Setup

### 1.1 Install Python 3.10

**Windows:**
```powershell
# Download Python 3.10.11 installer
# Install to: C:\Python310

# Verify installation
C:\Python310\python.exe --version
# Should output: Python 3.10.11
```

**Linux/Mac:**
```bash
# Install via pyenv (recommended)
pyenv install 3.10.11
pyenv local 3.10.11

# Or use system package manager
sudo apt install python3.10  # Ubuntu/Debian
brew install python@3.10      # macOS
```

### 1.2 Create Virtual Environment

Navigate to the AI service directory:

```powershell
# Windows
cd C:\Users\deeks\reclaim_flutter\ai_service
C:\Python310\python.exe -m venv venv
.\venv\Scripts\activate

# Linux/Mac
cd /path/to/reclaim_flutter/ai_service
python3.10 -m venv venv
source venv/bin/activate
```

You should see `(venv)` in your terminal prompt.

### 1.3 Install Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

**Expected output:**
```
Installing collected packages:
  - fastapi==0.104.1
  - uvicorn==0.24.0
  - tensorflow-cpu==2.12.0
  - numpy==1.23.5
  - scikit-learn==1.3.2
  - pydantic==2.5.0
Successfully installed...
```

### 1.4 Verify Installation

```python
python -c "import tensorflow as tf; import fastapi; print('✓ All dependencies installed')"
```

---

## 🎬 Step 2: Start AI Service

### 2.1 Manual Start

```bash
# Make sure virtual environment is activated
python app.py
```

**Expected output:**
```
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Initializing AI model...
INFO:     AI model loaded successfully (source: demo)
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### 2.2 Automatic Start (Background)

**Windows:**
```powershell
# Use the startup script
.\start_service.bat
```

**Linux/Mac:**
```bash
# Use the startup script
./start_service.sh
```

### 2.3 Verify Service is Running

Open browser: http://localhost:8000

You should see:
```json
{
  "service": "AI Recovery Plan Service",
  "version": "1.0.0",
  "status": "running",
  "endpoints": {
    "predict": "/get_recovery_plan",
    "health": "/health",
    "docs": "/docs"
  }
}
```

### 2.4 Check Health Endpoint

```bash
curl http://localhost:8000/health
```

Response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_source": "demo"
}
```

---

## 🧪 Step 3: Test AI Service

### 3.1 Test with curl

```bash
curl -X POST http://localhost:8000/get_recovery_plan \
  -H "Content-Type: application/json" \
  -d '{
    "addiction_type": "alcohol",
    "daily_usage": 60,
    "mood_score": 5,
    "task_completion_rate": 0.6,
    "relapse_count": 2
  }'
```

**Expected response:**
```json
{
  "risk_level": "medium",
  "confidence": 0.75,
  "goals": [
    "Reduce alcohol usage by 15% this week",
    "Complete daily recovery tasks",
    "Improve mood tracking consistency",
    "Build support network",
    "Practice stress management"
  ],
  "tips": [
    "Track your usage daily",
    "Join support group meetings",
    "Practice mindfulness"
  ],
  "source": "tensorflow",
  "model_version": "demo-1.0"
}
```

### 3.2 Test with Python Client

```powershell
# In a NEW terminal (Python 3.14 environment)
cd C:\Users\deeks\reclaim_flutter
python ml_ai_client.py
```

**Expected output:**
```
AI Recovery Plan Client Test
==================================================

Checking AI service health...
AI Service Status: ✓ Healthy

Low Risk User
--------------------------------------------------
Risk Level: LOW
Confidence: 85.0%
Source: tensorflow (vdemo-1.0)

Goals:
  1. Maintain current progress
  2. Continue daily tracking
  3. Stay engaged with support
  4. Practice healthy habits

Tips:
  • Keep up the good work
  • Stay consistent with routines
  • Reach out when needed

Medium Risk User
--------------------------------------------------
...
```

### 3.3 Interactive API Documentation

Open http://localhost:8000/docs in your browser.

This opens **Swagger UI** where you can:
- See all endpoints
- Try requests interactively
- View request/response schemas

---

## 🔗 Step 4: Integration with Main App

### 4.1 Update Main Application Code

Find where you currently generate recovery plans. Replace rule-based code with:

```python
from ml_ai_client import get_recovery_plan

# Example: In your user service
def create_recovery_plan_for_user(user_id: str):
    # Extract user data
    user_data = get_user_behavioral_data(user_id)
    
    # Get AI-powered plan
    plan = get_recovery_plan(
        addiction_type=user_data["addiction_type"],
        daily_usage=user_data["daily_usage"],
        mood_score=user_data["mood_score"],
        task_completion_rate=user_data["task_completion_rate"],
        relapse_count=user_data["relapse_count"],
    )
    
    # Use the plan
    save_recovery_plan(user_id, plan)
    return plan
```

### 4.2 Environment Configuration

Add to your `.env` file:

```bash
# AI Service Configuration
AI_SERVICE_URL=http://localhost:8000/get_recovery_plan
AI_SERVICE_TIMEOUT=5.0
AI_SERVICE_ENABLED=true
```

### 4.3 Error Handling

The client automatically falls back to rule-based if AI service is unavailable:

```python
plan = get_recovery_plan(...)

if plan.get("source") == "rule-based":
    logger.warning("Using fallback plan - AI service unavailable")
    # Optionally notify admin
    send_alert("AI service down, using fallback")
```

---

## 🏭 Step 5: Production Deployment

### 5.1 Using Systemd (Linux)

Create `/etc/systemd/system/ai-recovery-service.service`:

```ini
[Unit]
Description=AI Recovery Plan Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/reclaim_flutter/ai_service
Environment="PATH=/opt/reclaim_flutter/ai_service/venv/bin"
ExecStart=/opt/reclaim_flutter/ai_service/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Start service:
```bash
sudo systemctl daemon-reload
sudo systemctl start ai-recovery-service
sudo systemctl enable ai-recovery-service
sudo systemctl status ai-recovery-service
```

### 5.2 Using Windows Service

Install NSSM (Non-Sucking Service Manager):

```powershell
# Download NSSM
# Install service
nssm install AIRecoveryService "C:\Python310\python.exe"
nssm set AIRecoveryService AppDirectory "C:\Users\deeks\reclaim_flutter\ai_service"
nssm set AIRecoveryService AppParameters "app.py"
nssm start AIRecoveryService
```

### 5.3 Using Docker

Create `Dockerfile`:

```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["python", "app.py"]
```

Build and run:
```bash
docker build -t ai-recovery-service .
docker run -d -p 8000:8000 --name ai-service ai-recovery-service
```

### 5.4 Environment Variables

For production, set:

```bash
# Production settings
export AI_ENV=production
export AI_LOG_LEVEL=INFO
export AI_WORKERS=4
export AI_HOST=0.0.0.0
export AI_PORT=8000
```

### 5.5 Load Balancing (Optional)

For high availability, run multiple instances behind nginx:

```nginx
upstream ai_service {
    server localhost:8001;
    server localhost:8002;
    server localhost:8003;
}

server {
    listen 80;
    location /ai/ {
        proxy_pass http://ai_service/;
    }
}
```

---

## 📊 Step 6: Monitoring & Maintenance

### 6.1 Health Monitoring

Set up periodic health checks:

```python
# health_monitor.py
import requests
import time

while True:
    try:
        resp = requests.get("http://localhost:8000/health", timeout=2)
        if resp.json().get("status") == "healthy":
            print("✓ Service healthy")
        else:
            print("⚠ Service degraded")
    except Exception as e:
        print(f"✗ Service down: {e}")
    
    time.sleep(60)  # Check every minute
```

### 6.2 Logging

Logs are written to:
- **Console**: Real-time logs
- **File**: `logs/ai_service.log` (if configured)

View logs:
```bash
# Systemd
journalctl -u ai-recovery-service -f

# Docker
docker logs -f ai-service

# Manual
tail -f logs/ai_service.log
```

### 6.3 Performance Metrics

Monitor these metrics:
- **Request latency**: Should be < 200ms
- **Error rate**: Should be < 1%
- **CPU usage**: Should be < 50%
- **Memory**: Should be < 500MB

### 6.4 Model Updates

To update the AI model:

```bash
# 1. Train new model
cd ml_training
python train_recovery_plan_model.py

# 2. Copy to AI service
cp models/random_forest.pkl ../ai_service/models/

# 3. Restart service
sudo systemctl restart ai-recovery-service
```

---

## 🐛 Troubleshooting

### Issue: "Port 8000 already in use"

```bash
# Find process using port
netstat -ano | findstr :8000  # Windows
lsof -i :8000                 # Linux/Mac

# Kill process
taskkill /PID <pid> /F        # Windows
kill -9 <pid>                 # Linux/Mac
```

### Issue: "Module 'tensorflow' not found"

```bash
# Ensure virtual environment is activated
source venv/bin/activate  # Linux/Mac
.\venv\Scripts\activate   # Windows

# Reinstall TensorFlow
pip install tensorflow-cpu==2.12.0
```

### Issue: "AI service not responding"

1. Check if service is running:
   ```bash
   curl http://localhost:8000/health
   ```

2. Check logs for errors
3. Verify Python version:
   ```bash
   python --version  # Should be 3.10.x
   ```

4. Restart service:
   ```bash
   # Manual
   python app.py
   
   # Systemd
   sudo systemctl restart ai-recovery-service
   ```

### Issue: "High memory usage"

```python
# In app.py, reduce batch processing:
# Change from processing batches to single requests
# Add memory limits in Docker:
docker run --memory=512m ai-recovery-service
```

---

## ✅ Verification Checklist

Before going to production:

- [ ] Python 3.10 installed and verified
- [ ] Virtual environment created and activated
- [ ] All dependencies installed (requirements.txt)
- [ ] AI service starts without errors
- [ ] Health check returns "healthy"
- [ ] Test prediction works (curl/client)
- [ ] Main app integration tested
- [ ] Fallback to rule-based works
- [ ] Logging configured
- [ ] Monitoring set up
- [ ] Production service configured (systemd/Docker)
- [ ] Firewall rules configured (if needed)
- [ ] SSL/TLS configured (if external access)

---

## 📞 Support

If you encounter issues:
1. Check logs first
2. Verify all prerequisites
3. Test each component individually
4. Review this guide carefully

---

## 🎉 Success!

Your AI microservice is now deployed and integrated!

**Next steps:**
1. Monitor performance for first week
2. Collect user feedback
3. Train production models with real data
4. Expand features (add more behavioral signals)
5. Implement A/B testing (AI vs rule-based)

Happy deploying! 🚀

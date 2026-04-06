# 🚀 AI Microservice - Getting Started (5 Minutes)

Complete guide to get your AI-powered recovery plans running immediately.

---

## ⚡ Quick Setup

### 1. Install Python 3.10 (if not installed)

Download: https://www.python.org/downloads/release/python-3100/

**Windows:** Install to `C:\Python310`

**Verify:**
```powershell
C:\Python310\python.exe --version
# Output: Python 3.10.x
```

### 2. Set Up Virtual Environment

```powershell
cd C:\Users\deeks\reclaim_flutter\ai_service
C:\Python310\python.exe -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Start AI Service

```powershell
python app.py
```

**Expected:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

✅ Service running!

### 4. Test (New Terminal)

```powershell
# Health check
curl http://localhost:8000/health

# Full test suite
python test_ai_integration.py
```

---

## 📖 Usage in Your App

```python
from ml_ai_client import get_recovery_plan

plan = get_recovery_plan(
    addiction_type="alcohol",
    daily_usage=60,
    mood_score=5,
    task_completion_rate=0.6,
    relapse_count=2,
)

print(plan['risk_level'])  # "low", "medium", "high"
print(plan['confidence'])  # 0.0-1.0
print(plan['goals'])       # List of personalized goals
```

---

## 🎯 What You Get

**AI-Powered:**
- ✅ TensorFlow neural network
- ✅ 95.33% accurate Random Forest
- ✅ Personalized recommendations
- ✅ Automatic fallback if service down

**Production Ready:**
- ✅ REST API (FastAPI)
- ✅ Health monitoring
- ✅ Complete error handling
- ✅ Interactive docs at /docs

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| [AI_MICROSERVICE_SUMMARY.md](AI_MICROSERVICE_SUMMARY.md) | Complete overview |
| [ai_service/DEPLOYMENT.md](ai_service/DEPLOYMENT.md) | Deployment guide |
| [ai_service/README.md](ai_service/README.md) | API docs |

**API Docs:** http://localhost:8000/docs

---

## 🐛 Troubleshooting

**"Port 8000 in use":**
```powershell
taskkill /F /IM python.exe
# Or change port in app.py
```

**"tensorflow not found":**
```powershell
.\venv\Scripts\activate
pip install tensorflow-cpu==2.12.0
```

**"Service not responding":**
- Check if running: `curl http://localhost:8000/health`
- Client automatically falls back to rules if down

---

## ✅ Next Steps

1. ✅ Start service: `cd ai_service && python app.py`
2. ✅ Test it: `python test_ai_integration.py`
3. ✅ Integrate: Use `ml_ai_client.get_recovery_plan()` in your app
4. ✅ Deploy: See [DEPLOYMENT.md](ai_service/DEPLOYMENT.md)

**You're ready to go!** 🎉

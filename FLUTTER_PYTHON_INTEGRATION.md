# Flutter + Python API Integration Guide

## Overview

Your Flutter app now integrates with the Python FastAPI ML service for enhanced AI-powered recovery plan generation:

- **Python API (Primary)**: TensorFlow-based ML inference running on your local machine
- **TFLite (Fallback)**: Local on-device inference if API is unavailable
- **Automatic Failover**: Seamlessly falls back to TFLite if Python API is down

## Architecture

```
┌─────────────────┐
│  Flutter App    │
│                 │
│  ┌───────────┐  │      ┌──────────────────┐
│  │ AI Service│──┼─────►│ Python API       │
│  │           │  │ HTTP │ (127.0.0.1:8000) │
│  │  ├─ API   │  │      │                  │
│  │  └─TFLite │  │      │ ├─ TensorFlow    │
│  └───────────┘  │      │ ├─ scikit-learn  │
│                 │      │ └─ FastAPI       │
└─────────────────┘      └──────────────────┘
```

## Setup & Running

### 1. Start Python API (Required)

**Option A: Using VS Code Task**
```
Press Ctrl+Shift+B → Select "Start API + Flutter"
```

**Option B: Manual Terminal**
```powershell
# Terminal 1: Start Python API
.\.venv\Scripts\uvicorn.exe ai_service.app:app --reload --host 127.0.0.1 --port 8000

# Terminal 2: Run Flutter
flutter run
```

### 2. Verify API is Running

Open browser: http://127.0.0.1:8000/docs

You should see the FastAPI Swagger UI documentation.

### 3. Test the Integration

The Flutter app will automatically:
1. Check if Python API is available on startup
2. Use Python API for predictions if available
3. Fall back to local TFLite if API is down
4. Display which inference method was used in logs

## How It Works

### In Flutter (lib/services/ai_recovery_plan_service.dart)

```dart
// Service automatically chooses best inference method
final service = AIRecoveryPlanService();
await service.initialize(); // Checks API health + loads TFLite

// Generate plan (uses Python API if available, else TFLite)
final plan = await service.generateAIPlan(userId, 'alcohol');
```

### Integration Flow

1. **Initialization** (`initialize()`)
   - Checks Python API health (2s timeout)
   - Loads TFLite model as fallback
   - Logs which methods are available

2. **Plan Generation** (`generateAIPlan()`)
   - Extracts user features from Firestore
   - Tries Python API first if available
   - Falls back to TFLite on API error
   - Returns unified RecoveryPlanModel

3. **API Communication** (lib/services/ai_api_client.dart)
   - HTTP POST to `/get_recovery_plan`
   - Converts Flutter data → Python format
   - Handles Android emulator (10.0.2.2) vs desktop (127.0.0.1)

## API Endpoints

### POST /get_recovery_plan
```json
{
  "addiction_type": "alcohol",
  "daily_usage": 60.0,
  "mood_score": 5.0,
  "task_completion_rate": 0.6,
  "relapse_count": 2
}
```

**Response:**
```json
{
  "risk_level": "medium",
  "confidence": 0.85,
  "goals": ["Goal 1", "Goal 2", "Goal 3"],
  "tips": ["Tip 1", "Tip 2", "Tip 3"],
  "source": "ai",
  "model_version": "1.0.0"
}
```

### GET /health
Check if API is running and model is loaded.

## Platform-Specific Configuration

### Android Emulator
- Uses `10.0.2.2:8000` (emulator → host machine)
- Automatically handled in `AiApiClient`

### iOS Simulator / Desktop
- Uses `127.0.0.1:8000`
- Works out of the box

### Physical Device
- Update `baseUrl` in `AiApiClient` to your machine's LAN IP
- Example: `http://192.168.1.100:8000`

## Testing

### 1. Test Python API Directly
```powershell
# Using curl
curl -X POST http://127.0.0.1:8000/get_recovery_plan \
  -H "Content-Type: application/json" \
  -d '{"addiction_type":"alcohol","daily_usage":60,"mood_score":5,"task_completion_rate":0.6,"relapse_count":2}'

# Using Python
python -c "import requests; print(requests.get('http://127.0.0.1:8000/health').json())"
```

### 2. Test in Flutter
Use the demo screen:
```
lib/screens/ai_recovery_plan_demo_screen.dart
```

Check debug logs for inference source:
```
[AIRecoveryPlan] ✓ Python API available
[AIRecoveryPlan] ✓ ML Prediction (Python API (TensorFlow)): medium (confidence: 85.0%)
```

## Troubleshooting

### API Not Reachable
**Symptom:** "Python API unreachable" in logs

**Solution:**
1. Ensure Python API is running: `.\.venv\Scripts\uvicorn.exe ai_service.app:app --reload`
2. Check firewall isn't blocking port 8000
3. Verify `http://127.0.0.1:8000/health` works in browser

### Import Errors
**Symptom:** "ModuleNotFoundError: No module named 'model'"

**Solution:**
- Run API from project root with: `uvicorn ai_service.app:app`
- Don't run from `ai_service/` directory

### TFLite Fallback Always Used
**Symptom:** Always seeing "TFLite (local)" in logs

**Solution:**
1. Check API is running: `curl http://127.0.0.1:8000/health`
2. Increase timeout in `initialize()` if network is slow
3. Check Android emulator uses `10.0.2.2` not `127.0.0.1`

## Files Modified

- ✅ `lib/services/ai_api_client.dart` - HTTP client for Python API
- ✅ `lib/services/ai_recovery_plan_service.dart` - Integrated API + TFLite
- ✅ `pubspec.yaml` - Added `http` dependency
- ✅ `.vscode/tasks.json` - VS Code tasks to run both services
- ✅ `ai_service/app.py` - Fixed imports for module path

## Next Steps

1. **Enhance Features**: Add more user data to improve predictions
2. **Retrain Models**: Use real user data to retrain ML models
3. **Deploy API**: Host Python API on cloud (Render, Railway, AWS)
4. **Add Caching**: Cache predictions to reduce API calls
5. **Monitor Performance**: Track API response times and accuracy

## Development Workflow

```bash
# Start development environment
1. Open VS Code
2. Press Ctrl+Shift+B
3. Select "Start API + Flutter"
4. Both services start automatically

# Make changes
- Edit Python API: Hot reload automatic (uvicorn --reload)
- Edit Flutter: Hot reload with 'r' in terminal

# Debug
- Python API logs: Check uvicorn terminal output
- Flutter logs: Check Flutter terminal or VS Code Debug Console
```

## Production Deployment

### Option 1: Cloud API + Flutter App
1. Deploy Python API to Render/Railway/AWS
2. Update `AiApiClient._defaultBaseUrl` to production URL
3. Build Flutter app with production API endpoint

### Option 2: Embedded TFLite Only
1. Remove Python API dependency
2. App uses only local TFLite inference
3. Smaller, self-contained, but less powerful

## Performance Notes

- **Python API**: ~100-300ms (network + inference)
- **TFLite**: ~50-100ms (on-device only)
- **Accuracy**: Python API slightly better (more powerful models)
- **Offline**: TFLite works offline, Python API requires internet

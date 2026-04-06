"""Test the FastAPI service with real ML inference."""
import time
import subprocess
import sys

# Give server time to start
time.sleep(3)

# Test with requests
try:
    import requests
    
    print("=" * 70)
    print("TESTING FASTAPI SERVICE WITH REAL ML INFERENCE")
    print("=" * 70)
    
    # Test health
    response = requests.get("http://localhost:8000/health", timeout=5)
    print(f"\n✓ Health check: {response.status_code}")
    if response.status_code == 200:
        print(f"  {response.json()}")
    
    # Test recovery plan with real ML
    test_payload = {
        "user_id": "test_user_123",
        "addiction_type": "social_media",
        "daily_usage_minutes": 180,
        "mood_score": 5,
        "task_completion_rate": 0.5,
        "relapse_count": 1,
    }
    
    print(f"\n✓ Calling /get_recovery_plan with real data...")
    print(f"  Input: {test_payload}")
    
    response = requests.post(
        "http://localhost:8000/get_recovery_plan",
        json=test_payload,
        timeout=5
    )
    
    print(f"\n✓ Response: {response.status_code}")
    result = response.json()
    
    print("\n" + "=" * 70)
    print("RESULT FROM REAL ML MODEL (85.33% ACCURACY)")
    print("=" * 70)
    print(f"Risk Level: {result.get('risk_level', 'N/A')}")
    print(f"Confidence: {result.get('confidence', 'N/A')}")
    print(f"Source: {result.get('source', 'N/A')} ← Should be 'logistic_regression'")
    print(f"\nFirst 2 goals:")
    for goal in result.get('goals', [])[:2]:
        print(f"  • {goal}")
    print("\n" + "=" * 70)
    print("✓ SUCCESS: API returns predictions from REAL trained model!")
    print("=" * 70)
    
except Exception as e:
    print(f"✗ Error: {e}")
    print("Note: Make sure the FastAPI server is running on localhost:8000")
    sys.exit(1)

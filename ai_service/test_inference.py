"""Test real ML inference from trained model."""
import logging
logging.basicConfig(level=logging.INFO, format='%(message)s')

from model import model

# Test data
test_data = {
    "addiction_type": "social_media",
    "daily_usage_minutes": 240,
    "mood_score": 4,
    "task_completion_rate": 0.3,
    "relapse_count": 2,
}

print("=" * 60)
print("TESTING REAL ML INFERENCE")
print("=" * 60)
print(f"\nInput: {test_data}")
print(f"Model Source: {model.model_source}")
print(f"Model Loaded: {model.lr_model is not None}")

# Run prediction
result = model.predict(test_data)

print("\n" + "=" * 60)
print("PREDICTION RESULT (FROM 85.33% ACCURATE MODEL)")
print("=" * 60)
print(f"Risk Level: {result['risk_level']}")
print(f"Confidence: {result['confidence']:.1%}")
print(f"Source: {result['source']}")
print(f"\nGoals ({len(result['goals'])} total):")
for i, goal in enumerate(result['goals'][:3], 1):
    print(f"  {i}. {goal}")
print(f"\nTips ({len(result['tips'])} total):")
for i, tip in enumerate(result['tips'][:2], 1):
    print(f"  {i}. {tip}")
print("\n" + "=" * 60)

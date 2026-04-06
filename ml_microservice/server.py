"""
TensorFlow AI Microservice (Python 3.10)
---------------------------------------
- REST API (FastAPI)
- Loads a tiny TensorFlow model (or builds one on first run)
- Predicts relapse risk level: low / medium / high
- Generates a simple personalized recovery plan
- Designed to run isolated from the main Python 3.14 app
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import List, Literal

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

# ---------------------------
# Config
# ---------------------------
MODEL_PATH = Path("./model_artifacts/risk_classifier")
MODEL_PATH.mkdir(parents=True, exist_ok=True)

# ---------------------------
# Schemas
# ---------------------------
class PredictRequest(BaseModel):
    addiction_type: Literal["alcohol", "smoking", "gaming", "gambling", "other"] = Field(
        description="Type of addiction"
    )
    daily_usage: float = Field(..., ge=0, description="Minutes per day")
    mood_score: float = Field(..., ge=0, le=10, description="Mood rating 0-10")
    task_completion_rate: float = Field(..., ge=0, le=1, description="0-1 fraction of tasks completed")
    relapse_count: int = Field(..., ge=0, description="Relapses in last 30 days")

class PlanGoal(BaseModel):
    title: str
    description: str

class PredictResponse(BaseModel):
    risk_level: Literal["low", "medium", "high"]
    confidence: float
    goals: List[PlanGoal]
    tips: List[str]

# ---------------------------
# Model Utilities
# ---------------------------
def _build_model() -> tf.keras.Model:
    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=(5,)),
            tf.keras.layers.Dense(8, activation="relu"),
            tf.keras.layers.Dense(3, activation="softmax"),
        ]
    )
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy")
    return model


def _train_stub_model(model: tf.keras.Model, path: Path) -> tf.keras.Model:
    # Synthetic tiny dataset (for demo); replace with real training data later
    X = np.array(
        [
            [15, 7, 0.9, 0, 0],   # low
            [45, 5, 0.6, 1, 1],   # medium
            [90, 3, 0.4, 3, 2],   # high
            [120, 2, 0.3, 4, 3],  # high
            [30, 6, 0.7, 1, 1],   # medium
            [10, 8, 0.95, 0, 0],  # low
        ],
        dtype=np.float32,
    )
    y = np.array([0, 1, 2, 2, 1, 0], dtype=np.int32)

    model.fit(X, y, epochs=50, verbose=0)
    model.save(path)
    return model


def _load_or_create_model(path: Path) -> tf.keras.Model:
    if path.exists():
        return tf.keras.models.load_model(path)
    model = _build_model()
    return _train_stub_model(model, path)


def _normalize(req: PredictRequest) -> np.ndarray:
    # Simple scaling; adjust as needed
    usage = req.daily_usage / 120.0  # assuming 0-120 minutes typical
    mood = req.mood_score / 10.0
    task = req.task_completion_rate  # already 0-1
    relapse = min(req.relapse_count, 5) / 5.0
    addiction = {
        "alcohol": 0.2,
        "smoking": 0.4,
        "gaming": 0.6,
        "gambling": 0.8,
        "other": 1.0,
    }.get(req.addiction_type, 1.0)
    return np.array([[usage, mood, task, relapse, addiction]], dtype=np.float32)


def _risk_label(probabilities: np.ndarray) -> tuple[str, float]:
    idx = int(np.argmax(probabilities))
    label = {0: "low", 1: "medium", 2: "high"}[idx]
    return label, float(probabilities[idx])


def _goals_for(label: str) -> List[PlanGoal]:
    if label == "high":
        return [
            PlanGoal(title="Daily Check-in", description="Complete a 5-min reflection daily"),
            PlanGoal(title="Support Call", description="Call a trusted person every evening"),
            PlanGoal(title="Trigger Log", description="Log triggers and coping steps each day"),
        ]
    if label == "medium":
        return [
            PlanGoal(title="Task Streak", description="Finish at least one key task daily"),
            PlanGoal(title="Mood Track", description="Record mood twice a day"),
            PlanGoal(title="Weekend Plan", description="Schedule a healthy activity")
        ]
    return [
        PlanGoal(title="Maintain Routine", description="Keep daily routines and healthy breaks"),
        PlanGoal(title="Light Social", description="Check in with a friend twice this week"),
    ]


# ---------------------------
# App
# ---------------------------
app = FastAPI(title="AI Recovery Plan Service", version="1.0.0")

model = _load_or_create_model(MODEL_PATH)

@app.post("/predict", response_model=PredictResponse)
def predict(payload: PredictRequest):
    try:
        features = _normalize(payload)
        probabilities = model.predict(features, verbose=0)[0]
        risk, confidence = _risk_label(probabilities)
        goals = _goals_for(risk)
        tips = [
            "Stay hydrated and sleep 7-9 hours.",
            "Plan your day the night before.",
            "Replace one risky habit with a healthy one.",
        ]
        return PredictResponse(
            risk_level=risk,
            confidence=confidence,
            goals=goals,
            tips=tips,
        )
    except Exception as exc:  # pragma: no cover - simple demo
        raise HTTPException(status_code=500, detail=f"prediction failed: {exc}")


@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("server:app", host="0.0.0.0", port=int(os.getenv("PORT", 8000)), reload=False)

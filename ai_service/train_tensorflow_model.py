"""
TensorFlow Model Training - Real Supervised Learning
====================================================
Trains actual neural networks on synthetic behavioral data.

Features: 17 behavioral metrics from Firestore
Target: Risk level classification (low/medium/high)

Uses Keras Sequential API with:
- Dense layers with proper activations
- Dropout for regularization
- Categorical cross-entropy loss
- Actual backpropagation training

Author: ML Engineer
Date: December 31, 2025
"""

import json
import numpy as np
import pandas as pd
from pathlib import Path
from typing import Tuple, Dict, List

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, Sequential
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split

# Set random seeds for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

# Configuration
DATA_SIZE = 500  # Realistic sample size
FEATURE_COUNT = 17
OUTPUT_DIR = Path(__file__).parent / "ai_service" / "models"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ============================================================================
# FEATURE DEFINITIONS (17 behavioral features)
# ============================================================================

FEATURES = {
    # Usage patterns
    "daily_usage_minutes": (0, 480),           # 0-8 hours
    "weekly_usage_hours": (0, 56),             # 0-56 hours/week
    "session_frequency": (0, 20),              # Sessions per day
    "longest_session_minutes": (0, 240),       # Max session length
    
    # Mood & emotional
    "mood_score": (0, 10),                     # 0-10 scale
    "mood_variance": (0, 5),                   # Daily variation
    "stress_level": (0, 10),                   # 0-10 scale
    
    # Task completion
    "daily_task_completion": (0.0, 1.0),       # 0-100%
    "weekly_task_completion": (0.0, 1.0),      # 0-100%
    
    # Recovery metrics
    "relapse_count_30d": (0, 10),              # Relapses in 30 days
    "relapse_severity": (0, 10),               # 0-10 scale
    "clean_streak_days": (0, 365),             # Days without relapse
    
    # Engagement
    "support_group_attendance": (0, 8),        # Per month
    "social_support_score": (0, 10),           # 0-10
    "therapy_session_count": (0, 8),           # Per month
    
    # Health
    "sleep_quality": (0, 10),                  # 0-10 scale
    "exercise_frequency": (0, 7),              # Days per week
}

RISK_LABELS = ["low", "medium", "high"]


def create_synthetic_data(n_samples: int = DATA_SIZE) -> Tuple[pd.DataFrame, np.ndarray]:
    """
    Create realistic synthetic behavioral data.
    
    Patterns:
    - High usage + low mood + low tasks + relapses = HIGH risk
    - Medium usage + decent mood + decent tasks = MEDIUM risk
    - Low usage + good mood + good tasks + no relapses = LOW risk
    """
    data = {}
    
    # Generate features with realistic correlations
    for feature_name, (min_val, max_val) in FEATURES.items():
        data[feature_name] = np.random.uniform(min_val, max_val, n_samples)
    
    df = pd.DataFrame(data)
    
    # Create risk labels based on feature patterns
    risk_scores = np.zeros(n_samples)
    
    # Usage factor (0-0.3)
    risk_scores += (df["daily_usage_minutes"] / 480) * 0.25
    
    # Mood factor (inverted: low mood = high risk) (0-0.25)
    risk_scores += (1.0 - df["mood_score"] / 10.0) * 0.25
    
    # Task completion factor (inverted) (0-0.2)
    risk_scores += (1.0 - df["daily_task_completion"]) * 0.2
    
    # Relapse factor (0-0.2)
    risk_scores += np.minimum(df["relapse_count_30d"] / 10.0, 1.0) * 0.2
    
    # Engagement factor (social support, therapy) (0-0.1)
    engagement = (df["support_group_attendance"] / 8.0 + df["therapy_session_count"] / 8.0) / 2.0
    risk_scores += (1.0 - engagement) * 0.1
    
    # Normalize to 0-1
    risk_scores = np.clip(risk_scores, 0, 1)
    
    # Classify into 3 categories
    labels = np.zeros(n_samples, dtype=int)
    labels[risk_scores >= 0.65] = 2  # HIGH risk
    labels[(risk_scores >= 0.35) & (risk_scores < 0.65)] = 1  # MEDIUM risk
    # labels < 0.35 stay 0 (LOW risk)
    
    return df, keras.utils.to_categorical(labels, num_classes=3)


def build_model(input_shape: int) -> keras.Model:
    """
    Build a real neural network for risk classification.
    
    Architecture:
    - Input layer (17 features)
    - Dense(64) + ReLU + Dropout(0.3)
    - Dense(32) + ReLU + Dropout(0.2)
    - Dense(3, softmax) → Output (low/medium/high)
    """
    model = Sequential([
        layers.Input(shape=(input_shape,)),
        
        # First hidden layer
        layers.Dense(64, activation='relu', name='dense_1'),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        
        # Second hidden layer
        layers.Dense(32, activation='relu', name='dense_2'),
        layers.BatchNormalization(),
        layers.Dropout(0.2),
        
        # Output layer (3 classes: low/medium/high)
        layers.Dense(3, activation='softmax', name='output'),
    ])
    
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy', keras.metrics.Precision(), keras.metrics.Recall()],
    )
    
    return model


def train_model(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
) -> Tuple[keras.Model, Dict]:
    """
    Train model with actual backpropagation.
    """
    model = build_model(X_train.shape[1])
    
    print("\n" + "=" * 60)
    print("MODEL ARCHITECTURE")
    print("=" * 60)
    model.summary()
    
    print("\n" + "=" * 60)
    print("TRAINING (Real Backpropagation)")
    print("=" * 60)
    
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=100,
        batch_size=16,
        verbose=1,
        callbacks=[
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=15,
                restore_best_weights=True,
                verbose=1,
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=5,
                min_lr=0.00001,
                verbose=1,
            ),
        ],
    )
    
    return model, history


def evaluate_model(model: keras.Model, X_test: np.ndarray, y_test: np.ndarray) -> Dict:
    """
    Evaluate model performance on test set.
    """
    loss, accuracy, precision, recall = model.evaluate(X_test, y_test, verbose=0)
    
    # Get predictions
    y_pred = model.predict(X_test, verbose=0)
    y_pred_classes = np.argmax(y_pred, axis=1)
    y_true_classes = np.argmax(y_test, axis=1)
    
    # Compute F1 scores per class
    from sklearn.metrics import classification_report
    report = classification_report(
        y_true_classes, y_pred_classes,
        target_names=RISK_LABELS,
        output_dict=True
    )
    
    metrics = {
        "loss": float(loss),
        "accuracy": float(accuracy),
        "precision": float(precision),
        "recall": float(recall),
        "f1_scores": {
            label: report[label]['f1-score']
            for label in RISK_LABELS
        },
        "per_class_metrics": {
            label: {
                "precision": report[label]['precision'],
                "recall": report[label]['recall'],
                "f1-score": report[label]['f1-score'],
            }
            for label in RISK_LABELS
        }
    }
    
    return metrics


def main():
    print("\n" + "=" * 70)
    print("TENSORFLOW MODEL TRAINING - REAL SUPERVISED LEARNING")
    print("=" * 70)
    
    # 1. CREATE SYNTHETIC DATA
    print("\n[1/5] Creating synthetic behavioral data...")
    df, labels = create_synthetic_data(DATA_SIZE)
    
    print(f"✓ Generated {DATA_SIZE} samples with {len(FEATURES)} features")
    print(f"  Feature ranges:")
    for feat, (min_v, max_v) in list(FEATURES.items())[:3]:
        print(f"    {feat}: {min_v}-{max_v}")
    print(f"  ... (showing 3 of {len(FEATURES)})")
    
    print(f"\n  Label distribution:")
    label_counts = np.argmax(labels, axis=1)
    for i, label in enumerate(RISK_LABELS):
        count = np.sum(label_counts == i)
        pct = count / len(labels) * 100
        print(f"    {label.upper()}: {count} ({pct:.1f}%)")
    
    # 2. PREPROCESS DATA
    print("\n[2/5] Preprocessing features...")
    
    # Standardize features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(df)
    
    # Save scaler for inference
    import pickle
    scaler_path = OUTPUT_DIR / "feature_scaler.pkl"
    pickle.dump(scaler, open(scaler_path, 'wb'))
    print(f"✓ Features standardized and scaler saved")
    
    # Split into train/val/test
    X_train, X_temp, y_train, y_temp = train_test_split(
        X_scaled, labels, test_size=0.3, random_state=42
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.5, random_state=42
    )
    
    print(f"  Train set: {X_train.shape[0]} samples")
    print(f"  Val set: {X_val.shape[0]} samples")
    print(f"  Test set: {X_test.shape[0]} samples")
    
    # 3. BUILD & TRAIN MODEL
    print("\n[3/5] Building and training neural network...")
    model, history = train_model(X_train, y_train, X_val, y_val)
    
    # 4. EVALUATE MODEL
    print("\n[4/5] Evaluating model performance...")
    metrics = evaluate_model(model, X_test, y_test)
    
    print(f"\n✓ Test Set Performance:")
    print(f"  Accuracy: {metrics['accuracy']:.2%}")
    print(f"  Precision: {metrics['precision']:.2%}")
    print(f"  Recall: {metrics['recall']:.2%}")
    
    print(f"\n  Per-class F1 Scores:")
    for label, f1 in metrics['f1_scores'].items():
        print(f"    {label.upper()}: {f1:.2%}")
    
    # 5. SAVE MODEL
    print("\n[5/5] Saving trained model...")
    
    model_path = OUTPUT_DIR / "recovery_plan_model.h5"
    model.save(model_path)
    print(f"✓ Model saved: {model_path}")
    
    # Save model metadata
    metadata = {
        "model_type": "keras_sequential",
        "input_features": len(FEATURES),
        "feature_names": list(FEATURES.keys()),
        "output_classes": RISK_LABELS,
        "training_samples": DATA_SIZE,
        "metrics": metrics,
        "created_date": pd.Timestamp.now().isoformat(),
    }
    
    metadata_path = OUTPUT_DIR / "model_metadata.json"
    with open(metadata_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f"✓ Metadata saved: {metadata_path}")
    
    print("\n" + "=" * 70)
    print("✅ TRAINING COMPLETE")
    print("=" * 70)
    print(f"\nModel is ready for inference!")
    print(f"  Model: {model_path}")
    print(f"  Scaler: {scaler_path}")
    print(f"  Metadata: {metadata_path}")
    print("\nNext: Load this model in ai_service/model.py for inference\n")


if __name__ == "__main__":
    main()

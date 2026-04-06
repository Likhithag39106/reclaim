# ML Model Training Guide

Welcome to the Reclaim AI Training Pipeline! This directory contains all the tools you need to train and deploy AI-powered recovery plans.

## 🚀 Quick Start (Complete Pipeline)

The easiest way to get started is using the automated pipeline:

```bash
cd ml_training
pip install -r requirements.txt
python quick_start.py
```

This will:
1. Extract user behavioral data from Firestore (or generate synthetic data)
2. Train 3 ML models (Logistic Regression, Decision Tree, Random Forest)
3. Convert the best model to TensorFlow Lite for mobile
4. Validate all outputs

**Estimated Time**: 5-10 minutes

## 📋 Manual Step-by-Step Process

If you prefer manual control:

### Step 1: Install Dependencies
```bash
pip install -r requirements.txt
```

### Step 2: Extract Data
```bash
python data_extraction.py
```
Output: `data/user_features.csv`

### Step 3: Train Models
```bash
python train_recovery_plan_model.py
```
Output: `models/*.pkl`, `models/model_metadata.json`

### Step 4: Convert to TFLite
```bash
python convert_to_tflite.py
```
Output: `../assets/models/recovery_plan_classifier.tflite`

## 🎯 Two AI Systems

This project includes two complementary AI systems:

### 1. Relapse Risk Prediction (Existing)
- **File**: `train_model_simple.py`
- **Purpose**: Predict probability of relapse
- **Output**: Single value (0.0-1.0)
- **Use Case**: Real-time risk monitoring

### 2. Personalized Recovery Plans (NEW - AI-Based)
- **Files**: `data_extraction.py`, `train_recovery_plan_model.py`, `convert_to_tflite.py`
- **Purpose**: Generate personalized recovery strategies
- **Output**: Severity classification (LOW/MEDIUM/HIGH) + confidence score
- **Use Case**: Adaptive treatment planning

## Model Details

**Input Features (10):**
1. Task completion rate (0-1)
2. Average mood score (0-1, normalized)
3. Days since relapse (0-1, normalized by 365)
4. Current streak (0-1, normalized by 90 days)
5. Average daily sessions (0-1, normalized by 20)
6. Average session duration (0-1, normalized by 60 min)
7. Days inactive (0-1, normalized by 7)
8. Mood variance (0-1)
9. Weekend/weekday ratio (0-1)
10. Time irregularity (0-1)

**Output:**
- Single value: Relapse probability (0.0 to 1.0)

**Architecture:**
- Input layer: 10 features
- Hidden layer 1: 16 neurons (ReLU activation)
- Dropout: 20%
- Hidden layer 2: 8 neurons (ReLU activation)  
- Dropout: 20%
- Hidden layer 3: 4 neurons (ReLU activation)
- Output layer: 1 neuron (Sigmoid activation)

**Training:**
- 50 epochs
- Batch size: 32
- Optimizer: Adam
- Loss: Binary crossentropy
- Metrics: Accuracy, AUC

**Model Size:** ~15 KB (optimized for mobile)

## For Production

Replace synthetic training data with real anonymized user data:

```python
# Instead of synthetic data:
X, y = load_real_user_data()  # Load from anonymized database
```

Expected accuracy with real data: >75%
Current accuracy with synthetic data: ~65-70%

## Testing

After training, test in the Flutter app:

1. Run the app
2. Go to Dashboard
3. Tap "Analyze Risk" button
4. Check if "ML" badge appears (indicates model loaded successfully)
5. Verify prediction completes within 100ms

## Troubleshooting

**"Model not found" error:**
- Ensure `relapse_predictor.tflite` is in `assets/models/`
- Check `pubspec.yaml` has `assets: - assets/models/`
- Run `flutter pub get` and restart app

**"Failed to load model" error:**
- App will automatically use rule-based fallback
- Check console for detailed error message
- Verify .tflite file is valid (not corrupted)

**Slow inference (>100ms):**
- Model might be too large
- Try quantization in training script
- Check device performance

## References

- [TensorFlow Lite Guide](https://www.tensorflow.org/lite/guide)
- [Flutter TFLite Package](https://pub.dev/packages/tflite_flutter)
- [Model Optimization](https://www.tensorflow.org/lite/performance/model_optimization)

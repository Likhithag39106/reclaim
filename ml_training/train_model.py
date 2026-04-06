"""
RECLAIM - Relapse Risk Prediction Model Training Script

This script trains a TensorFlow Lite model for on-device relapse risk prediction.
The model uses 10 behavioral features to predict relapse probability.

Features (normalized 0-1):
0. Task completion rate
1. Average mood (normalized)
2. Days since last relapse (normalized by 365)
3. Current streak (normalized by 90 days)
4. Average daily sessions (normalized by 20)
5. Average session duration (normalized by 60 min)
6. Days inactive in last week (normalized by 7)
7. Mood variance
8. Weekend/weekday usage ratio
9. Time irregularity

Output: Relapse probability [0.0, 1.0]
"""

import tensorflow as tf
import numpy as np
import os

def generate_synthetic_data(num_samples=1000):
    """
    Generate synthetic training data for relapse prediction.
    In production, replace with real anonymized user data.
    """
    np.random.seed(42)
    
    # Generate 10 features (all normalized 0-1)
    X = np.random.rand(num_samples, 10).astype(np.float32)
    
    # Generate labels based on realistic patterns
    # High risk factors: low completion, low mood, short streak, high inactivity
    risk_scores = (
        (1.0 - X[:, 0]) * 0.25 +  # Low task completion → higher risk
        (1.0 - X[:, 1]) * 0.20 +  # Low mood → higher risk
        (1.0 - X[:, 3]) * 0.15 +  # Short streak → higher risk
        X[:, 6] * 0.15 +           # More inactive days → higher risk
        X[:, 7] * 0.10 +           # Higher mood variance → higher risk
        X[:, 9] * 0.10 +           # Higher time irregularity → higher risk
        np.random.rand(num_samples) * 0.05  # Add noise
    )
    
    # Convert to binary labels (threshold at 0.5)
    y = (risk_scores > 0.5).astype(np.float32)
    
    # Also return continuous scores for validation
    return X, y, risk_scores

def create_relapse_model():
    """
    Create a small neural network for relapse prediction.
    Architecture optimized for mobile deployment.
    """
    model = tf.keras.Sequential([
        # Input layer: 10 features
        tf.keras.layers.InputLayer(input_shape=(10,)),
        
        # Hidden layer 1: 16 neurons with dropout
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        
        # Hidden layer 2: 8 neurons with dropout
        tf.keras.layers.Dense(8, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        
        # Hidden layer 3: 4 neurons
        tf.keras.layers.Dense(4, activation='relu'),
        
        # Output layer: probability
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    
    model.compile(
        optimizer='adam',
        loss='binary_crossentropy',
        metrics=['accuracy', tf.keras.metrics.AUC(name='auc')]
    )
    
    return model

def train_and_export_model():
    """
    Train the model and export to TensorFlow Lite format.
    """
    print("[Training] Generating synthetic training data...")
    X_train, y_train, _ = generate_synthetic_data(num_samples=800)
    X_test, y_test, _ = generate_synthetic_data(num_samples=200)
    
    print("[Training] Creating model architecture...")
    model = create_relapse_model()
    model.summary()
    
    print("\n[Training] Training model...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=50,
        batch_size=32,
        verbose=1
    )
    
    # Evaluate model
    print("\n[Evaluation] Testing model performance...")
    test_loss, test_acc, test_auc = model.evaluate(X_test, y_test, verbose=0)
    print(f"Test Accuracy: {test_acc:.4f}")
    print(f"Test AUC: {test_auc:.4f}")
    print(f"Test Loss: {test_loss:.4f}")
    
    # Convert to TensorFlow Lite
    print("\n[Export] Converting to TensorFlow Lite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Optional: Use float16 quantization for smaller model
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    # Create output directory
    output_dir = '../assets/models'
    os.makedirs(output_dir, exist_ok=True)
    
    # Save TFLite model
    output_path = os.path.join(output_dir, 'relapse_predictor.tflite')
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    model_size_kb = len(tflite_model) / 1024
    print(f"\n[Success] Model exported to: {output_path}")
    print(f"Model size: {model_size_kb:.2f} KB")
    
    # Test TFLite model inference
    print("\n[Validation] Testing TFLite inference...")
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Test with sample input
    test_input = np.random.rand(1, 10).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    tflite_output = interpreter.get_tensor(output_details[0]['index'])
    
    # Compare with original model
    keras_output = model.predict(test_input, verbose=0)
    
    print(f"Keras output: {keras_output[0][0]:.4f}")
    print(f"TFLite output: {tflite_output[0][0]:.4f}")
    print(f"Difference: {abs(keras_output[0][0] - tflite_output[0][0]):.6f}")
    
    print("\n[Complete] Model training and export successful!")
    return history, model

if __name__ == '__main__':
    print("=" * 60)
    print("RECLAIM Relapse Risk Prediction Model Training")
    print("=" * 60)
    
    # Check TensorFlow version
    print(f"\nTensorFlow version: {tf.__version__}")
    
    # Train and export
    history, model = train_and_export_model()
    
    print("\n" + "=" * 60)
    print("Training Complete!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Run 'flutter pub get' to install tflite_flutter dependency")
    print("2. Place the model file in assets/models/ directory")
    print("3. Test inference in the Flutter app")
    print("4. Replace synthetic data with real anonymized user data for better accuracy")

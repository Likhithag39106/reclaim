"""
Alternative Model Training Script using Keras (simpler setup)

This script uses pure Keras which may have better Windows compatibility.
Run this on a machine with Python 3.8-3.11 and pip install tensorflow.

If TensorFlow installation fails, you can:
1. Use Google Colab (free): https://colab.research.google.com/
2. Copy this script to Colab
3. Run it to generate the .tflite model
4. Download and place in assets/models/

For now, the app will use rule-based prediction as fallback.
"""

try:
    import tensorflow as tf
    import numpy as np
    import os
    
    print(f"TensorFlow version: {tf.__version__}")
    print(f"GPU available: {tf.config.list_physical_devices('GPU')}")
    
    def generate_synthetic_data(num_samples=1000):
        """Generate synthetic training data"""
        np.random.seed(42)
        X = np.random.rand(num_samples, 10).astype(np.float32)
        
        # Risk calculation
        risk_scores = (
            (1.0 - X[:, 0]) * 0.25 +  # Low completion
            (1.0 - X[:, 1]) * 0.20 +  # Low mood
            (1.0 - X[:, 3]) * 0.15 +  # Short streak
            X[:, 6] * 0.15 +           # Inactive days
            X[:, 7] * 0.10 +           # Mood variance
            X[:, 9] * 0.10 +           # Time irregularity
            np.random.rand(num_samples) * 0.05
        )
        
        y = (risk_scores > 0.5).astype(np.float32)
        return X, y, risk_scores
    
    def create_model():
        """Create neural network"""
        model = tf.keras.Sequential([
            tf.keras.layers.InputLayer(input_shape=(10,)),
            tf.keras.layers.Dense(16, activation='relu'),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(8, activation='relu'),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(4, activation='relu'),
            tf.keras.layers.Dense(1, activation='sigmoid')
        ])
        
        model.compile(
            optimizer='adam',
            loss='binary_crossentropy',
            metrics=['accuracy', tf.keras.metrics.AUC(name='auc')]
        )
        
        return model
    
    print("\n[1/4] Generating training data...")
    X_train, y_train, _ = generate_synthetic_data(800)
    X_test, y_test, _ = generate_synthetic_data(200)
    print(f"Training samples: {len(X_train)}")
    print(f"Test samples: {len(X_test)}")
    
    print("\n[2/4] Building model...")
    model = create_model()
    model.summary()
    
    print("\n[3/4] Training model (this may take a few minutes)...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=50,
        batch_size=32,
        verbose=1
    )
    
    # Evaluate
    test_loss, test_acc, test_auc = model.evaluate(X_test, y_test, verbose=0)
    print(f"\n[Evaluation]")
    print(f"  Test Accuracy: {test_acc:.4f}")
    print(f"  Test AUC: {test_auc:.4f}")
    print(f"  Test Loss: {test_loss:.4f}")
    
    print("\n[4/4] Converting to TensorFlow Lite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    # Check if running in Colab
    in_colab = 'google.colab' in str(get_ipython()) if 'get_ipython' in dir() else False
    
    if in_colab:
        # Save to root in Colab for easy download
        output_path = 'relapse_predictor.tflite'
        print(f"[Colab Mode] Saving to: {output_path}")
    else:
        # Save to assets/models for local development
        output_dir = '../assets/models'
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, 'relapse_predictor.tflite')
        print(f"[Local Mode] Saving to: {output_path}")
    
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    model_size_kb = len(tflite_model) / 1024
    print(f"\n[SUCCESS] Model saved to: {output_path}")
    print(f"Model size: {model_size_kb:.2f} KB")
    
    # Verify TFLite model
    print("\n[Verification] Testing TFLite model...")
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    
    test_input = np.random.rand(1, 10).astype(np.float32)
    interpreter.set_tensor(interpreter.get_input_details()[0]['index'], test_input)
    interpreter.invoke()
    tflite_output = interpreter.get_tensor(interpreter.get_output_details()[0]['index'])
    
    keras_output = model.predict(test_input, verbose=0)
    print(f"Keras output: {keras_output[0][0]:.4f}")
    print(f"TFLite output: {tflite_output[0][0]:.4f}")
    print(f"Difference: {abs(keras_output[0][0] - tflite_output[0][0]):.6f}")
    
    print("\n" + "="*60)
    print("MODEL TRAINING COMPLETE!")
    print("="*60)
    print("\nNext steps:")
    print("1. Copy the .tflite file to your Flutter project's assets/models/")
    print("2. Run 'flutter pub get' in your Flutter project")
    print("3. Test the ML prediction in your app")
    print("4. For production: train with real user data for better accuracy")
    
except ImportError as e:
    print("="*60)
    print("ERROR: TensorFlow not installed")
    print("="*60)
    print(f"\nDetails: {e}")
    print("\nTo install TensorFlow:")
    print("  pip install tensorflow")
    print("\nOr use Google Colab (recommended for Windows):")
    print("  1. Go to: https://colab.research.google.com/")
    print("  2. Copy this entire script")
    print("  3. Run it in a new notebook")
    print("  4. Download the generated .tflite file")
    print("  5. Place it in: assets/models/relapse_predictor.tflite")
    print("\nThe app will use rule-based prediction until model is available.")
    print("="*60)

except Exception as e:
    print(f"\nERROR during training: {e}")
    import traceback
    traceback.print_exc()

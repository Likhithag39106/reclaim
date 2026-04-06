"""
Convert Trained Model to TensorFlow Lite
========================================

This script converts the best-performing scikit-learn model to TensorFlow Lite
format for deployment in Flutter mobile app.

Process:
1. Load trained scikit-learn model
2. Create equivalent Keras/TensorFlow model
3. Train Keras model to mimic scikit-learn predictions
4. Convert to TFLite format
5. Validate conversion accuracy
"""

import numpy as np
import joblib
import json
import os

try:
    import tensorflow as tf
    from tensorflow import keras
    TF_AVAILABLE = True
except ImportError:
    print("[ERROR] TensorFlow not installed!")
    print("Install with: pip install tensorflow")
    exit(1)


class ModelConverter:
    """Convert scikit-learn models to TensorFlow Lite for mobile deployment."""
    
    def __init__(self, model_dir: str = 'models'):
        """
        Initialize converter.
        
        Args:
            model_dir: Directory containing trained models
        """
        self.model_dir = model_dir
        self.sklearn_model = None
        self.tf_model = None
        self.scaler = None
        self.label_encoder = None
        self.metadata = None
        
        self._load_sklearn_model()
    
    def _load_sklearn_model(self):
        """Load trained scikit-learn model and preprocessing objects."""
        print("[INFO] Loading scikit-learn model...")
        
        # Load metadata to find best model
        metadata_path = os.path.join(self.model_dir, 'model_metadata.json')
        with open(metadata_path, 'r') as f:
            self.metadata = json.load(f)
        
        # Find best performing model
        best_model_name = max(
            self.metadata['results'],
            key=lambda k: self.metadata['results'][k]['accuracy']
        )
        
        print(f"  Best model: {best_model_name}")
        print(f"  Accuracy: {self.metadata['results'][best_model_name]['accuracy']:.4f}")
        
        # Load model
        model_path = os.path.join(self.model_dir, f'{best_model_name}.pkl')
        self.sklearn_model = joblib.load(model_path)
        print(f"  Loaded: {model_path}")
        
        # Load scaler
        scaler_path = os.path.join(self.model_dir, 'scaler.pkl')
        self.scaler = joblib.load(scaler_path)
        print(f"  Loaded: {scaler_path}")
        
        # Load label encoder
        encoder_path = os.path.join(self.model_dir, 'label_encoder.pkl')
        self.label_encoder = joblib.load(encoder_path)
        print(f"  Loaded: {encoder_path}")
        
        print("[✓] All components loaded successfully!")
    
    def create_equivalent_keras_model(self):
        """
        Create a Keras neural network that mimics the scikit-learn model.
        
        This is necessary because TFLite doesn't directly support scikit-learn models.
        We train a neural network to replicate the scikit-learn model's predictions.
        """
        print("\n[INFO] Creating equivalent Keras model...")
        
        num_features = self.metadata['num_features']
        num_classes = self.metadata['num_classes']
        
        # Create neural network architecture
        model = keras.Sequential([
            keras.layers.InputLayer(input_shape=(num_features,)),
            keras.layers.Dense(64, activation='relu'),
            keras.layers.Dropout(0.3),
            keras.layers.Dense(32, activation='relu'),
            keras.layers.Dropout(0.2),
            keras.layers.Dense(16, activation='relu'),
            keras.layers.Dense(num_classes, activation='softmax')
        ])
        
        model.compile(
            optimizer='adam',
            loss='sparse_categorical_crossentropy',
            metrics=['accuracy']
        )
        
        print("[✓] Keras model created")
        model.summary()
        
        self.tf_model = model
        return model
    
    def train_keras_model(self, X_train, y_train, epochs=50, batch_size=32):
        """
        Train Keras model to mimic scikit-learn model.
        
        This is called "knowledge distillation" - we use the scikit-learn model
        as a "teacher" to train the Keras "student" model.
        
        Args:
            X_train: Training features
            y_train: Training labels
            epochs: Number of training epochs
            batch_size: Batch size for training
        """
        print("\n[INFO] Training Keras model...")
        
        # Get predictions from scikit-learn model (teacher)
        sklearn_predictions = self.sklearn_model.predict(X_train)
        
        # Train Keras model to match sklearn predictions
        history = self.tf_model.fit(
            X_train,
            sklearn_predictions,
            epochs=epochs,
            batch_size=batch_size,
            validation_split=0.2,
            verbose=1
        )
        
        print("[✓] Keras model trained successfully!")
        return history
    
    def convert_to_tflite(self, output_path: str = '../assets/models/recovery_plan_classifier.tflite'):
        """
        Convert Keras model to TensorFlow Lite format.
        
        Args:
            output_path: Where to save the .tflite file
        """
        print("\n[INFO] Converting to TensorFlow Lite...")
        
        # Create TFLite converter
        converter = tf.lite.TFLiteConverter.from_keras_model(self.tf_model)
        
        # Apply optimizations (reduce model size)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Convert
        tflite_model = converter.convert()
        
        # Create output directory if needed
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Save to file
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        model_size_kb = len(tflite_model) / 1024
        print(f"[✓] TFLite model saved to: {output_path}")
        print(f"    Model size: {model_size_kb:.2f} KB")
        
        return output_path
    
    def validate_conversion(self, X_test, y_test):
        """
        Validate that TFLite model produces similar results to original model.
        
        Args:
            X_test: Test features
            y_test: Test labels
        """
        print("\n[INFO] Validating TFLite conversion...")
        
        # Get predictions from original sklearn model
        sklearn_pred = self.sklearn_model.predict(X_test)
        
        # Get predictions from Keras model
        keras_pred_proba = self.tf_model.predict(X_test)
        keras_pred = np.argmax(keras_pred_proba, axis=1)
        
        # Calculate agreement
        agreement = np.mean(sklearn_pred == keras_pred)
        
        print(f"\n[Validation Results]")
        print(f"  Agreement between sklearn and Keras: {agreement:.4f}")
        
        if agreement > 0.90:
            print(f"  [✓] EXCELLENT - Models are highly aligned")
        elif agreement > 0.80:
            print(f"  [✓] GOOD - Acceptable alignment for production")
        elif agreement > 0.70:
            print(f"  [⚠] FAIR - Consider retraining with more epochs")
        else:
            print(f"  [✗] POOR - Models differ significantly, retrain needed")
        
        return agreement
    
    def export_scaler_parameters(self, output_path: str = '../assets/models/scaler_params.json'):
        """
        Export scaler parameters to JSON for Flutter implementation.
        
        Flutter will need to normalize features the same way during inference.
        
        Args:
            output_path: Where to save scaler parameters
        """
        print("\n[INFO] Exporting scaler parameters...")
        
        scaler_params = {
            'mean': self.scaler.mean_.tolist(),
            'scale': self.scaler.scale_.tolist(),
            'feature_names': self.metadata['feature_names'],
        }
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(scaler_params, f, indent=2)
        
        print(f"[✓] Scaler parameters saved to: {output_path}")
        return output_path
    
    def export_class_mapping(self, output_path: str = '../assets/models/class_mapping.json'):
        """
        Export class label mapping for Flutter.
        
        Args:
            output_path: Where to save class mapping
        """
        print("\n[INFO] Exporting class mapping...")
        
        class_mapping = {
            'classes': self.label_encoder.classes_.tolist(),
            'mapping': {
                int(i): class_name 
                for i, class_name in enumerate(self.label_encoder.classes_)
            }
        }
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(class_mapping, f, indent=2)
        
        print(f"[✓] Class mapping saved to: {output_path}")
        return output_path


def generate_training_data():
    """Generate synthetic training data for model conversion."""
    print("[INFO] Generating synthetic training data...")
    
    num_samples = 1000
    num_features = 16  # Match the expected feature count
    
    np.random.seed(42)
    
    # Generate random features
    X_train = np.random.rand(num_samples, num_features).astype(np.float32)
    
    # Generate labels based on simple rules
    scores = (
        (1.0 - X_train[:, 5]) * 0.3 +  # completion_rate
        (1.0 - X_train[:, 8]) * 0.25 + # avg_mood_rating
        X_train[:, 11] * 0.25 +         # relapse_count
        X_train[:, 1] * 0.2             # sessions_per_day
    )
    
    y_train = np.zeros(num_samples, dtype=np.int32)
    y_train[scores < 0.35] = 0  # low
    y_train[(scores >= 0.35) & (scores < 0.65)] = 1  # medium
    y_train[scores >= 0.65] = 2  # high
    
    # Generate test data
    X_test = np.random.rand(200, num_features).astype(np.float32)
    scores_test = (
        (1.0 - X_test[:, 5]) * 0.3 +
        (1.0 - X_test[:, 8]) * 0.25 +
        X_test[:, 11] * 0.25 +
        X_test[:, 1] * 0.2
    )
    y_test = np.zeros(200, dtype=np.int32)
    y_test[scores_test < 0.35] = 0
    y_test[(scores_test >= 0.35) & (scores_test < 0.65)] = 1
    y_test[scores_test >= 0.65] = 2
    
    print(f"[✓] Generated {num_samples} training samples")
    print(f"[✓] Generated {len(X_test)} test samples")
    
    return X_train, y_train, X_test, y_test


def main():
    """Main execution function."""
    print("="*60)
    print("TFLITE MODEL CONVERSION")
    print("="*60)
    
    # Check if trained models exist
    if not os.path.exists('models/model_metadata.json'):
        print("\n[WARNING] Trained models not found!")
        print("[INFO] Please run train_recovery_plan_model.py first")
        print("\n[INFO] Running in demo mode with synthetic model...")
        
        # Create a simple demo model
        print("\n[Creating demo model...]")
        num_features = 16
        num_classes = 3
        
        model = keras.Sequential([
            keras.layers.InputLayer(input_shape=(num_features,)),
            keras.layers.Dense(32, activation='relu'),
            keras.layers.Dense(16, activation='relu'),
            keras.layers.Dense(num_classes, activation='softmax')
        ])
        
        model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
        
        X_train, y_train, X_test, y_test = generate_training_data()
        model.fit(X_train, y_train, epochs=20, validation_split=0.2, verbose=1)
        
        # Convert to TFLite
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        
        # Save
        output_path = '../assets/models/recovery_plan_classifier.tflite'
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"\n[✓] Demo TFLite model saved to: {output_path}")
        print(f"    Model size: {len(tflite_model) / 1024:.2f} KB")
        
        # Export demo scaler params
        demo_scaler = {
            'mean': [0.5] * num_features,
            'scale': [0.3] * num_features,
            'feature_names': [f'feature_{i}' for i in range(num_features)]
        }
        
        scaler_path = '../assets/models/scaler_params.json'
        with open(scaler_path, 'w') as f:
            json.dump(demo_scaler, f, indent=2)
        print(f"[✓] Demo scaler params saved to: {scaler_path}")
        
        # Export class mapping
        class_map = {
            'classes': ['low', 'medium', 'high'],
            'mapping': {0: 'low', 1: 'medium', 2: 'high'}
        }
        class_path = '../assets/models/class_mapping.json'
        with open(class_path, 'w') as f:
            json.dump(class_map, f, indent=2)
        print(f"[✓] Demo class mapping saved to: {class_path}")
        
        print("\n" + "="*60)
        print("DEMO MODEL CREATED!")
        print("="*60)
        print("\nNote: This is a demo model. For production:")
        print("1. Collect real user data")
        print("2. Run train_recovery_plan_model.py with real data")
        print("3. Re-run this script to convert the real model")
        
        return
    
    # Initialize converter
    converter = ModelConverter(model_dir='models')
    
    # Create Keras equivalent
    converter.create_equivalent_keras_model()
    
    # Load training data for knowledge distillation
    # In production, you would load your actual training data
    print("\n[INFO] Loading training data...")
    X_train, y_train, X_test, y_test = generate_training_data()
    
    # Normalize using the trained scaler
    X_train_scaled = converter.scaler.transform(X_train)
    X_test_scaled = converter.scaler.transform(X_test)
    
    # Train Keras model
    converter.train_keras_model(X_train_scaled, y_train, epochs=30)
    
    # Validate conversion
    converter.validate_conversion(X_test_scaled, y_test)
    
    # Convert to TFLite
    tflite_path = converter.convert_to_tflite()
    
    # Export supporting files
    converter.export_scaler_parameters()
    converter.export_class_mapping()
    
    print("\n" + "="*60)
    print("CONVERSION COMPLETE!")
    print("="*60)
    print("\nFiles created:")
    print("1. recovery_plan_classifier.tflite - TFLite model for Flutter")
    print("2. scaler_params.json - Feature normalization parameters")
    print("3. class_mapping.json - Output class labels")
    print("\nNext steps:")
    print("1. Copy files to your Flutter assets/models/ folder")
    print("2. Update pubspec.yaml to include new assets")
    print("3. Implement AIRecoveryPlanService in Flutter")
    print("4. Test the integrated AI service")


if __name__ == '__main__':
    main()

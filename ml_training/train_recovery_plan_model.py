"""
AI-Based Recovery Plan Classification Model Training
====================================================

This script trains machine learning models to predict optimal recovery plan
severity levels based on user behavioral data.

Models Trained:
1. Logistic Regression (baseline, interpretable)
2. Decision Tree (rule-based, explainable)
3. Random Forest (ensemble, best performance)

Output:
- Trained models (.pkl files)
- TensorFlow Lite model for Flutter deployment
- Performance metrics and evaluation reports
"""

import pandas as pd
import numpy as np
import json
import joblib
from datetime import datetime
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier, export_text
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    classification_report, 
    confusion_matrix, 
    accuracy_score,
    precision_recall_fscore_support,
    roc_auc_score
)
import matplotlib.pyplot as plt
import seaborn as sns

# Try to import TensorFlow (optional for deployment)
try:
    import tensorflow as tf
    TF_AVAILABLE = True
except ImportError:
    print("[WARNING] TensorFlow not installed. TFLite conversion will be skipped.")
    TF_AVAILABLE = False


class RecoveryPlanMLTrainer:
    """
    Machine Learning trainer for recovery plan classification.
    
    This class handles:
    1. Data preprocessing and feature engineering
    2. Model training (Logistic Regression, Decision Tree, Random Forest)
    3. Model evaluation and comparison
    4. Model export for deployment
    """
    
    def __init__(self, data_path: str = 'training_data_raw.csv'):
        """
        Initialize trainer with data.
        
        Args:
            data_path: Path to extracted user data CSV
        """
        self.data_path = data_path
        self.df = None
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None
        self.scaler = None
        self.label_encoder = None
        self.feature_names = None
        
        self.models = {}
        self.results = {}
        
        print("[INFO] Initializing Recovery Plan ML Trainer...")
    
    def load_and_preprocess_data(self):
        """
        Load data from CSV and perform preprocessing.
        
        Steps:
        1. Load CSV data
        2. Handle missing values
        3. Encode categorical variables
        4. Create target labels (severity levels)
        5. Normalize numerical features
        """
        print("\n[Step 1/6] Loading data...")
        
        try:
            self.df = pd.read_csv(self.data_path)
            print(f"  Loaded {len(self.df)} users with {len(self.df.columns)} features")
        except FileNotFoundError:
            print(f"[ERROR] File not found: {self.data_path}")
            print("[INFO] Generating synthetic data for demonstration...")
            self.df = self._generate_synthetic_labeled_data(500)
        
        print("\n[Step 2/6] Handling missing values...")
        # Fill missing numerical values with median
        numerical_cols = self.df.select_dtypes(include=[np.number]).columns
        self.df[numerical_cols] = self.df[numerical_cols].fillna(self.df[numerical_cols].median())
        
        # Fill missing categorical values with mode
        categorical_cols = self.df.select_dtypes(include=['object']).columns
        for col in categorical_cols:
            if col not in ['uid', 'created_at']:  # Skip ID columns
                self.df[col] = self.df[col].fillna(self.df[col].mode()[0] if len(self.df[col].mode()) > 0 else 'unknown')
        
        print(f"  Missing values handled")
        
        print("\n[Step 3/6] Engineering target labels...")
        # Create target variable: severity_level (low, medium, high)
        self.df['severity_level'] = self.df.apply(self._calculate_severity_level, axis=1)
        
        print("  Severity distribution:")
        print(self.df['severity_level'].value_counts())
        
        print("\n[Step 4/6] Preparing features...")
        # Select feature columns (exclude ID and target)
        feature_cols = [
            # Usage features
            'avg_session_duration_min',
            'sessions_per_day',
            'max_session_duration_min',
            'late_night_sessions',
            'weekend_session_ratio',
            
            # Task features
            'completion_rate',
            'current_streak_days',
            'avg_completion_time_hours',
            
            # Mood features
            'avg_mood_rating',
            'mood_variance',
            'trigger_count',
            
            # Relapse features
            'relapse_count',
            'days_since_last_relapse',
            'relapse_frequency',
            
            # Engagement features
            'engagement_rate',
            'unique_active_days',
        ]
        
        # Ensure all feature columns exist
        feature_cols = [col for col in feature_cols if col in self.df.columns]
        self.feature_names = feature_cols
        
        print(f"  Selected {len(feature_cols)} features")
        
        # Encode categorical addiction types
        if 'addiction' in self.df.columns:
            addiction_dummies = pd.get_dummies(self.df['addiction'], prefix='addiction')
            self.df = pd.concat([self.df, addiction_dummies], axis=1)
            feature_cols.extend(addiction_dummies.columns.tolist())
            self.feature_names = feature_cols
        
        # Encode mood trend
        if 'mood_trend' in self.df.columns:
            mood_trend_map = {'improving': 1, 'stable': 0, 'declining': -1}
            self.df['mood_trend_encoded'] = self.df['mood_trend'].map(mood_trend_map).fillna(0)
            feature_cols.append('mood_trend_encoded')
            self.feature_names = feature_cols
        
        print("\n[Step 5/6] Splitting data...")
        # Prepare X and y
        X = self.df[feature_cols].values
        y = self.df['severity_level'].values
        
        # Encode labels (low=0, medium=1, high=2)
        self.label_encoder = LabelEncoder()
        y_encoded = self.label_encoder.fit_transform(y)
        
        # Split data (70% train, 30% test)
        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            X, y_encoded, test_size=0.3, random_state=42, stratify=y_encoded
        )
        
        print(f"  Training set: {len(self.X_train)} samples")
        print(f"  Test set: {len(self.X_test)} samples")
        
        print("\n[Step 6/6] Normalizing features...")
        # Normalize features using StandardScaler
        self.scaler = StandardScaler()
        self.X_train = self.scaler.fit_transform(self.X_train)
        self.X_test = self.scaler.transform(self.X_test)
        
        print("  Features normalized (mean=0, std=1)")
        print("\n[✓] Data preprocessing complete!")
    
    def _calculate_severity_level(self, row) -> str:
        """
        Calculate severity level based on user behavior.
        
        This is a rule-based heuristic for labeling training data.
        In production, labels should come from clinical assessments or outcomes.
        
        Severity factors:
        - High relapse frequency → HIGH
        - Low completion rate + high usage → HIGH
        - Poor mood + triggers → MEDIUM/HIGH
        - Good progress → LOW
        """
        score = 0
        
        # Relapse indicators (40% weight)
        if row.get('relapse_count', 0) >= 3:
            score += 40
        elif row.get('relapse_count', 0) >= 1:
            score += 20
        
        if row.get('days_since_last_relapse', 365) < 7:
            score += 20
        elif row.get('days_since_last_relapse', 365) < 30:
            score += 10
        
        # Task completion (25% weight)
        completion_rate = row.get('completion_rate', 0.5)
        if completion_rate < 0.3:
            score += 25
        elif completion_rate < 0.6:
            score += 12
        
        # Usage patterns (20% weight)
        avg_session = row.get('avg_session_duration_min', 30)
        sessions_per_day = row.get('sessions_per_day', 3)
        
        if avg_session > 90 or sessions_per_day > 10:
            score += 20
        elif avg_session > 60 or sessions_per_day > 6:
            score += 10
        
        # Mood indicators (15% weight)
        avg_mood = row.get('avg_mood_rating', 3.0)
        mood_variance = row.get('mood_variance', 0.5)
        
        if avg_mood < 2.5 or mood_variance > 1.5:
            score += 15
        elif avg_mood < 3.5 or mood_variance > 1.0:
            score += 7
        
        # Classify severity
        if score >= 60:
            return 'high'
        elif score >= 30:
            return 'medium'
        else:
            return 'low'
    
    def train_models(self):
        """
        Train multiple ML models and compare performance.
        
        Models:
        1. Logistic Regression - Fast, interpretable baseline
        2. Decision Tree - Explainable decision rules
        3. Random Forest - Best accuracy (ensemble)
        """
        print("\n" + "="*60)
        print("MODEL TRAINING")
        print("="*60)
        
        # 1. Logistic Regression
        print("\n[Model 1/3] Training Logistic Regression...")
        lr_model = LogisticRegression(
            max_iter=1000,
            class_weight='balanced',  # Handle class imbalance
            random_state=42
        )
        lr_model.fit(self.X_train, self.y_train)
        self.models['logistic_regression'] = lr_model
        
        # Cross-validation
        cv_scores = cross_val_score(lr_model, self.X_train, self.y_train, cv=5)
        print(f"  Cross-validation accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")
        
        # 2. Decision Tree
        print("\n[Model 2/3] Training Decision Tree...")
        dt_model = DecisionTreeClassifier(
            max_depth=8,  # Prevent overfitting
            min_samples_split=20,
            min_samples_leaf=10,
            class_weight='balanced',
            random_state=42
        )
        dt_model.fit(self.X_train, self.y_train)
        self.models['decision_tree'] = dt_model
        
        cv_scores = cross_val_score(dt_model, self.X_train, self.y_train, cv=5)
        print(f"  Cross-validation accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")
        
        # 3. Random Forest
        print("\n[Model 3/3] Training Random Forest...")
        rf_model = RandomForestClassifier(
            n_estimators=100,
            max_depth=10,
            min_samples_split=15,
            class_weight='balanced',
            random_state=42,
            n_jobs=-1  # Use all CPU cores
        )
        rf_model.fit(self.X_train, self.y_train)
        self.models['random_forest'] = rf_model
        
        cv_scores = cross_val_score(rf_model, self.X_train, self.y_train, cv=5)
        print(f"  Cross-validation accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")
        
        print("\n[✓] All models trained successfully!")
    
    def evaluate_models(self):
        """
        Evaluate all models on test set and generate comparison reports.
        """
        print("\n" + "="*60)
        print("MODEL EVALUATION")
        print("="*60)
        
        for model_name, model in self.models.items():
            print(f"\n{'='*60}")
            print(f"{model_name.upper().replace('_', ' ')}")
            print('='*60)
            
            # Predictions
            y_pred = model.predict(self.X_test)
            y_pred_proba = model.predict_proba(self.X_test) if hasattr(model, 'predict_proba') else None
            
            # Accuracy
            accuracy = accuracy_score(self.y_test, y_pred)
            print(f"\nAccuracy: {accuracy:.4f}")
            
            # Classification report
            print("\nClassification Report:")
            target_names = self.label_encoder.classes_
            print(classification_report(self.y_test, y_pred, target_names=target_names))
            
            # Confusion matrix
            cm = confusion_matrix(self.y_test, y_pred)
            print("\nConfusion Matrix:")
            print(cm)
            
            # Store results
            self.results[model_name] = {
                'accuracy': accuracy,
                'predictions': y_pred,
                'probabilities': y_pred_proba,
                'confusion_matrix': cm.tolist(),
            }
            
            # Feature importance (for tree-based models)
            if model_name in ['decision_tree', 'random_forest']:
                print("\nTop 10 Most Important Features:")
                importances = model.feature_importances_
                indices = np.argsort(importances)[::-1][:10]
                
                for i, idx in enumerate(indices, 1):
                    feature_name = self.feature_names[idx] if idx < len(self.feature_names) else f'Feature {idx}'
                    print(f"  {i}. {feature_name}: {importances[idx]:.4f}")
        
        # Model comparison
        print("\n" + "="*60)
        print("MODEL COMPARISON")
        print("="*60)
        print("\n{:<25} {:<15}".format("Model", "Accuracy"))
        print("-"*40)
        for model_name, results in self.results.items():
            print("{:<25} {:<15.4f}".format(model_name.replace('_', ' ').title(), results['accuracy']))
        
        # Select best model
        best_model_name = max(self.results, key=lambda k: self.results[k]['accuracy'])
        print(f"\n[✓] Best Model: {best_model_name.replace('_', ' ').title()}")
        print(f"    Accuracy: {self.results[best_model_name]['accuracy']:.4f}")
        
        return best_model_name
    
    def save_models(self, output_dir: str = 'models'):
        """
        Save trained models to disk.
        
        Saves:
        - .pkl files for each model (scikit-learn)
        - scaler.pkl (StandardScaler)
        - label_encoder.pkl (LabelEncoder)
        - model_metadata.json (feature names, classes, etc.)
        """
        import os
        os.makedirs(output_dir, exist_ok=True)
        
        print("\n" + "="*60)
        print("SAVING MODELS")
        print("="*60)
        
        # Save each model
        for model_name, model in self.models.items():
            model_path = os.path.join(output_dir, f'{model_name}.pkl')
            joblib.dump(model, model_path)
            print(f"[✓] Saved: {model_path}")
        
        # Save scaler
        scaler_path = os.path.join(output_dir, 'scaler.pkl')
        joblib.dump(self.scaler, scaler_path)
        print(f"[✓] Saved: {scaler_path}")
        
        # Save label encoder
        encoder_path = os.path.join(output_dir, 'label_encoder.pkl')
        joblib.dump(self.label_encoder, encoder_path)
        print(f"[✓] Saved: {encoder_path}")
        
        # Save metadata
        metadata = {
            'feature_names': self.feature_names,
            'num_features': len(self.feature_names),
            'classes': self.label_encoder.classes_.tolist(),
            'num_classes': len(self.label_encoder.classes_),
            'training_date': datetime.now().isoformat(),
            'training_samples': len(self.X_train),
            'test_samples': len(self.X_test),
            'results': {k: {'accuracy': v['accuracy']} for k, v in self.results.items()},
        }
        
        metadata_path = os.path.join(output_dir, 'model_metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        print(f"[✓] Saved: {metadata_path}")
        
        print("\n[✓] All models saved successfully!")
    
    def export_decision_rules(self, output_file: str = 'models/decision_rules.txt'):
        """
        Export human-readable decision rules from Decision Tree.
        
        This is useful for understanding the model's logic and for
        educational purposes.
        """
        if 'decision_tree' not in self.models:
            print("[WARNING] Decision Tree model not found. Skipping rule export.")
            return
        
        print("\n[INFO] Exporting decision rules...")
        
        dt_model = self.models['decision_tree']
        rules = export_text(dt_model, feature_names=self.feature_names)
        
        with open(output_file, 'w') as f:
            f.write("DECISION TREE RULES FOR RECOVERY PLAN CLASSIFICATION\n")
            f.write("="*60 + "\n\n")
            f.write(f"Classes: {self.label_encoder.classes_}\n")
            f.write(f"  0 = {self.label_encoder.classes_[0]}\n")
            f.write(f"  1 = {self.label_encoder.classes_[1]}\n")
            f.write(f"  2 = {self.label_encoder.classes_[2]}\n\n")
            f.write("="*60 + "\n\n")
            f.write(rules)
        
        print(f"[✓] Decision rules saved to: {output_file}")
    
    def _generate_synthetic_labeled_data(self, num_samples: int = 500) -> pd.DataFrame:
        """Generate synthetic data with labels for testing."""
        print(f"[INFO] Generating {num_samples} synthetic samples...")
        
        np.random.seed(42)
        data = []
        
        for _ in range(num_samples):
            # Generate correlated features
            base_severity = np.random.choice(['low', 'medium', 'high'], p=[0.4, 0.4, 0.2])
            
            if base_severity == 'low':
                completion_rate = np.random.uniform(0.7, 0.95)
                avg_mood = np.random.uniform(3.5, 4.8)
                relapse_count = np.random.choice([0, 1], p=[0.8, 0.2])
                avg_session = np.random.uniform(10, 45)
                sessions_per_day = np.random.uniform(1, 4)
            elif base_severity == 'medium':
                completion_rate = np.random.uniform(0.4, 0.7)
                avg_mood = np.random.uniform(2.5, 3.8)
                relapse_count = np.random.choice([0, 1, 2], p=[0.3, 0.5, 0.2])
                avg_session = np.random.uniform(30, 75)
                sessions_per_day = np.random.uniform(3, 8)
            else:  # high
                completion_rate = np.random.uniform(0.1, 0.5)
                avg_mood = np.random.uniform(1.5, 3.0)
                relapse_count = np.random.randint(2, 6)
                avg_session = np.random.uniform(60, 150)
                sessions_per_day = np.random.uniform(6, 15)
            
            sample = {
                'uid': f'user_{_}',
                'addiction': np.random.choice(['Social Media', 'Gaming', 'Substance', 'Gambling']),
                'avg_session_duration_min': avg_session,
                'sessions_per_day': sessions_per_day,
                'max_session_duration_min': avg_session * np.random.uniform(1.2, 2.0),
                'late_night_sessions': int(sessions_per_day * 30 * np.random.uniform(0.1, 0.4)),
                'weekend_session_ratio': np.random.uniform(0.2, 0.5),
                'total_tasks': np.random.randint(20, 100),
                'completed_tasks': 0,  # Will calculate
                'completion_rate': completion_rate,
                'avg_completion_time_hours': np.random.uniform(2, 48),
                'current_streak_days': int(completion_rate * 30),
                'total_mood_logs': np.random.randint(10, 60),
                'avg_mood_rating': avg_mood,
                'mood_variance': np.random.uniform(0.3, 2.0),
                'mood_trend': np.random.choice(['improving', 'stable', 'declining']),
                'trigger_count': np.random.randint(0, 20),
                'relapse_count': relapse_count,
                'days_since_last_relapse': 7 if relapse_count > 0 else np.random.randint(30, 365),
                'relapse_frequency': relapse_count / 30.0,
                'total_logins': np.random.randint(20, 100),
                'unique_active_days': int(completion_rate * 30),
                'engagement_rate': completion_rate,
            }
            
            sample['completed_tasks'] = int(sample['total_tasks'] * completion_rate)
            data.append(sample)
        
        return pd.DataFrame(data)


def main():
    """Main execution function."""
    print("="*60)
    print("AI-BASED RECOVERY PLAN MODEL TRAINING")
    print("="*60)
    
    # Initialize trainer
    trainer = RecoveryPlanMLTrainer('training_data_raw.csv')
    
    # Load and preprocess data
    trainer.load_and_preprocess_data()
    
    # Train models
    trainer.train_models()
    
    # Evaluate models
    best_model = trainer.evaluate_models()
    
    # Save models
    trainer.save_models(output_dir='models')
    
    # Export decision rules
    trainer.export_decision_rules()
    
    print("\n" + "="*60)
    print("TRAINING COMPLETE!")
    print("="*60)
    print("\nNext steps:")
    print("1. Review model performance metrics above")
    print("2. Check decision_rules.txt for interpretable logic")
    print("3. Run convert_to_tflite.py to create Flutter-compatible model")
    print("4. Integrate the AI service into your Flutter app")


if __name__ == '__main__':
    main()

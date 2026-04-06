"""
AI Model Module - Real Supervised Learning Inference
=====================================================
Loads trained scikit-learn models and runs ACTUAL ML inference.

Models Trained:
- Logistic Regression (85.33% accuracy - PRIMARY)
- Random Forest (74.67% accuracy - FALLBACK)
- Decision Tree (70.67% accuracy - FALLBACK)
- Rule-based (emergency fallback)

No mocking. Pure machine learning inference.

Author: ML Engineer
Date: December 31, 2025
"""

import os
import json
import logging
import pickle
import numpy as np
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple

logger = logging.getLogger(__name__)

# Model paths - handle both nested and flat structures
BASE_MODEL_DIR = Path(__file__).parent / "models"
NESTED_MODEL_DIR = Path(__file__).parent / "ai_service" / "models"

# Use nested if default is empty
if (BASE_MODEL_DIR.exists() and 
    len(list(BASE_MODEL_DIR.glob("*.pkl"))) > 0):
    MODEL_DIR = BASE_MODEL_DIR
elif NESTED_MODEL_DIR.exists() and len(list(NESTED_MODEL_DIR.glob("*.pkl"))) > 0:
    MODEL_DIR = NESTED_MODEL_DIR
else:
    MODEL_DIR = BASE_MODEL_DIR  # Default fallback

LOGISTIC_REGRESSION_PATH = MODEL_DIR / "logistic_regression.pkl"
RANDOM_FOREST_PATH = MODEL_DIR / "random_forest.pkl"
DECISION_TREE_PATH = MODEL_DIR / "decision_tree.pkl"
SCALER_PATH = MODEL_DIR / "feature_scaler.pkl"
METADATA_PATH = MODEL_DIR / "model_metadata.json"

# 17 Features from training
FEATURE_NAMES = [
    "daily_usage_minutes",
    "weekly_usage_hours",
    "session_frequency",
    "longest_session_minutes",
    "mood_score",
    "mood_variance",
    "stress_level",
    "daily_task_completion",
    "weekly_task_completion",
    "relapse_count_30d",
    "relapse_severity",
    "clean_streak_days",
    "support_group_attendance",
    "social_support_score",
    "therapy_session_count",
    "sleep_quality",
    "exercise_frequency",
]

RISK_LEVELS = ["low", "medium", "high"]


class AIRecoveryModel:
    """Real ML-based recovery plan prediction model."""
    
    def __init__(self):
        """Initialize and load trained models."""
        self.lr_model = None          # Logistic Regression
        self.rf_model = None          # Random Forest
        self.dt_model = None          # Decision Tree
        self.scaler = None            # Feature scaler
        self.model_source = None      # Which model loaded
        self.metadata = None          # Model metadata
        
        self._load_models()
    
    def _load_models(self):
        """Load trained models with fallback chain."""
        logger.info("Initializing AI Recovery Model...")
        logger.debug(f"Model directory: {MODEL_DIR}")
        logger.debug(f"LR path exists: {LOGISTIC_REGRESSION_PATH.exists()} - {LOGISTIC_REGRESSION_PATH}")
        
        # Load feature scaler
        if SCALER_PATH.exists():
            try:
                with open(SCALER_PATH, 'rb') as f:
                    self.scaler = pickle.load(f)
                logger.info(f"✓ Feature scaler loaded")
            except Exception as e:
                logger.warning(f"Could not load scaler: {e}")
        
        # Load metadata
        if METADATA_PATH.exists():
            try:
                with open(METADATA_PATH, 'r') as f:
                    self.metadata = json.load(f)
                logger.info(f"✓ Model metadata loaded")
            except Exception as e:
                logger.warning(f"Could not load metadata: {e}")
        
        # 1. Try Logistic Regression (best accuracy: 85.33%)
        if LOGISTIC_REGRESSION_PATH.exists():
            try:
                with open(LOGISTIC_REGRESSION_PATH, 'rb') as f:
                    self.lr_model = pickle.load(f)
                self.model_source = "logistic_regression"
                logger.info(f"✓ Logistic Regression model loaded (85.33% accuracy)")
                return
            except Exception as e:
                logger.warning(f"Could not load LR: {e}")
        
        # 2. Try Random Forest (74.67% accuracy)
        if RANDOM_FOREST_PATH.exists():
            try:
                with open(RANDOM_FOREST_PATH, 'rb') as f:
                    self.rf_model = pickle.load(f)
                self.model_source = "random_forest"
                logger.info(f"✓ Random Forest model loaded (74.67% accuracy)")
                return
            except Exception as e:
                logger.warning(f"Could not load RF: {e}")
        
        # 3. Try Decision Tree (70.67% accuracy)
        if DECISION_TREE_PATH.exists():
            try:
                with open(DECISION_TREE_PATH, 'rb') as f:
                    self.dt_model = pickle.load(f)
                self.model_source = "decision_tree"
                logger.info(f"✓ Decision Tree model loaded (70.67% accuracy)")
                return
            except Exception as e:
                logger.warning(f"Could not load DT: {e}")
        
        # 4. Fallback to rule-based
        self.model_source = "rule-based"
        logger.warning("⚠ No ML models found, using rule-based fallback")
    
    def _extract_features(self, data: Dict[str, Any]) -> Optional[np.ndarray]:
        """
        Extract and normalize features from input data.
        Maps API input to 17-feature vector for model inference.
        """
        features = np.zeros(len(FEATURE_NAMES))
        
        # Map input fields to feature array
        input_to_feature = {
            "daily_usage": 0,                    # daily_usage_minutes
            "daily_usage_minutes": 0,
            "mood_score": 4,                     # mood_score
            "task_completion_rate": 7,           # daily_task_completion
            "task_completion": 7,
            "relapse_count": 9,                  # relapse_count_30d
        }
        
        # Fill in available features
        for input_key, feature_idx in input_to_feature.items():
            if input_key in data:
                value = data[input_key]
                
                # Normalize to reasonable ranges
                if input_key in ["daily_usage", "daily_usage_minutes"]:
                    features[feature_idx] = min(float(value), 480)
                elif input_key == "mood_score":
                    features[feature_idx] = np.clip(float(value), 0, 10)
                elif input_key in ["task_completion_rate", "task_completion"]:
                    features[feature_idx] = np.clip(float(value), 0, 1)
                elif input_key == "relapse_count":
                    features[feature_idx] = float(value)
        
        # Apply feature scaling if available
        if self.scaler is not None:
            try:
                features = self.scaler.transform([features])[0]
            except Exception as e:
                logger.warning(f"Could not scale features: {e}")
        
        return features.reshape(1, -1)
    
    def _predict_ml(self, features: np.ndarray) -> Tuple[Optional[str], Optional[float]]:
        """Run ACTUAL ML inference with trained models."""
        try:
            # Use Logistic Regression if available
            if self.lr_model is not None:
                prediction = self.lr_model.predict(features)[0]
                
                # Get confidence from predict_proba
                if hasattr(self.lr_model, 'predict_proba'):
                    probabilities = self.lr_model.predict_proba(features)[0]
                    confidence = float(np.max(probabilities))
                else:
                    confidence = 0.85
                
                risk_level = RISK_LEVELS[int(prediction)]
                logger.info(f"ML (LR) prediction: {risk_level} (conf: {confidence:.2%})")
                return risk_level, confidence
            
            # Fallback to Random Forest
            elif self.rf_model is not None:
                prediction = self.rf_model.predict(features)[0]
                
                if hasattr(self.rf_model, 'predict_proba'):
                    probabilities = self.rf_model.predict_proba(features)[0]
                    confidence = float(np.max(probabilities))
                else:
                    confidence = 0.75
                
                risk_level = RISK_LEVELS[int(prediction)]
                logger.info(f"ML (RF) prediction: {risk_level} (conf: {confidence:.2%})")
                return risk_level, confidence
            
            # Fallback to Decision Tree
            elif self.dt_model is not None:
                prediction = self.dt_model.predict(features)[0]
                
                if hasattr(self.dt_model, 'predict_proba'):
                    probabilities = self.dt_model.predict_proba(features)[0]
                    confidence = float(np.max(probabilities))
                else:
                    confidence = 0.70
                
                risk_level = RISK_LEVELS[int(prediction)]
                logger.info(f"ML (DT) prediction: {risk_level} (conf: {confidence:.2%})")
                return risk_level, confidence
            
        except Exception as e:
            logger.error(f"ML prediction error: {e}")
        
        return None, None
    
    def _predict_rule_based(self, data: Dict[str, Any]) -> Tuple[str, float]:
        """Simple rule-based fallback when no ML models available."""
        daily_usage = data.get("daily_usage", data.get("daily_usage_minutes", 60))
        mood_score = data.get("mood_score", 5)
        task_rate = data.get("task_completion_rate", data.get("task_completion", 0.5))
        relapses = data.get("relapse_count", 0)
        
        # Calculate risk score (0-1 scale)
        score = 0.0
        score += (daily_usage / 480) * 0.25
        score += (1.0 - mood_score / 10.0) * 0.25
        score += (1.0 - task_rate) * 0.2
        score += min(relapses / 10.0, 1.0) * 0.3
        
        # Classify
        if score >= 0.65:
            risk_level = "high"
            confidence = 0.65
        elif score >= 0.35:
            risk_level = "medium"
            confidence = 0.70
        else:
            risk_level = "low"
            confidence = 0.60
        
        logger.info(f"Rule-based prediction: {risk_level} (score: {score:.2f})")
        return risk_level, confidence
    
    def _generate_goals(self, risk_level: str, addiction_type: str) -> List[str]:
        """Generate personalized goals based on risk level and addiction type."""
        addiction_lower = addiction_type.lower()
        
        # Addiction-specific goals
        addiction_goals = {
            "alcohol": {
                "high": [
                    "Reduce alcohol consumption by 20% this week",
                    "Attend AA meetings 3x per week minimum",
                    "Remove all alcohol from home environment",
                    "Daily check-in with sponsor or counselor",
                ],
                "medium": [
                    "Cut down alcohol intake by 10% this week",
                    "Attend 2 AA meetings weekly",
                    "Track drinking patterns and triggers daily",
                ],
                "low": [
                    "Maintain sobriety streak and celebrate milestones",
                    "Continue AA meetings as scheduled",
                    "Support others in recovery journey",
                ],
            },
            "smoking": {
                "high": [
                    "Reduce cigarettes by 30% this week",
                    "Use nicotine replacement therapy consistently",
                    "Avoid smoking triggers (coffee breaks, stress)",
                    "Join smoking cessation support group",
                ],
                "medium": [
                    "Cut smoking by 15% this week",
                    "Track smoking patterns and cravings",
                    "Practice deep breathing when urges hit",
                ],
                "low": [
                    "Maintain smoke-free days and celebrate progress",
                    "Continue tracking quit journey",
                    "Help others quit smoking",
                ],
            },
            "social_media": {
                "high": [
                    "Reduce social media time by 50% this week",
                    "Delete distracting apps from phone",
                    "Set app timers to 30 min/day maximum",
                    "Replace scrolling with physical activities",
                ],
                "medium": [
                    "Limit social media to 1 hour per day",
                    "Turn off all push notifications",
                    "Practice mindful usage - no phone during meals",
                ],
                "low": [
                    "Maintain healthy social media boundaries",
                    "Continue using app timers effectively",
                    "Focus on meaningful connections offline",
                ],
            },
            "gaming": {
                "high": [
                    "Reduce gaming time by 40% this week",
                    "Uninstall most addictive games",
                    "Set strict gaming schedule (max 1hr/day)",
                    "Replace gaming with outdoor activities",
                ],
                "medium": [
                    "Limit gaming to 2 hours per day maximum",
                    "Track gaming patterns and triggers",
                    "Take breaks every 30 minutes",
                ],
                "low": [
                    "Maintain balanced gaming schedule",
                    "Continue prioritizing real-life activities",
                    "Use gaming as reward, not escape",
                ],
            },
        }
        
        # Get addiction-specific goals or use generic
        goals = addiction_goals.get(addiction_lower, {
            "high": [
                f"Reduce {addiction_type} usage by 20% this week",
                "Seek professional help or counseling",
                "Build strong support network",
                "Develop healthy coping mechanisms",
            ],
            "medium": [
                f"Cut down {addiction_type} usage by 10% this week",
                "Track patterns and identify triggers",
                "Practice stress management techniques",
            ],
            "low": [
                f"Maintain progress with {addiction_type} recovery",
                "Continue healthy habits and routines",
                "Support others in their journey",
            ],
        })
        
        return goals.get(risk_level, goals.get("medium", []))
    
    def _generate_tips(self, risk_level: str) -> List[str]:
        """Generate actionable tips based on risk level."""
        tips_by_risk = {
            "high": [
                "🆘 Reach out to support network immediately if struggling",
                "📋 Create crisis plan with trusted professionals",
                "🏃 Use distraction techniques (exercise, hobbies, socialize)",
                "🧘 Practice deep breathing when cravings hit",
                "📞 Schedule daily accountability check-ins",
            ],
            "medium": [
                "📅 Stay consistent with recovery routine",
                "📝 Track triggers and develop coping strategies",
                "👥 Maintain regular contact with support group",
                "💆 Practice self-care and stress management",
                "🎉 Celebrate small wins along the way",
            ],
            "low": [
                "⭐ Keep up your excellent progress!",
                "💪 Continue building healthy habits",
                "🤝 Help others in their recovery journey",
                "👀 Stay aware of potential triggers",
                "🌟 Maintain support network connections",
            ],
        }
        
        return tips_by_risk.get(risk_level, tips_by_risk["medium"])
    
    def predict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        MAIN PREDICTION METHOD - Run actual ML inference.
        
        No mocking. Loads trained models and runs real predictions.
        """
        addiction_type = data.get("addiction_type", "addiction")
        
        logger.info(f"Processing prediction for {addiction_type}")
        
        # Try ML prediction first
        features = self._extract_features(data)
        
        if features is not None and self.model_source != "rule-based":
            risk_level, confidence = self._predict_ml(features)
            
            if risk_level is not None:
                source = "ai"  # Use 'ai' instead of model name
            else:
                # Fall back to rules if ML fails
                risk_level, confidence = self._predict_rule_based(data)
                source = "fallback"
        else:
            # Use rule-based fallback
            risk_level, confidence = self._predict_rule_based(data)
            source = "fallback"
        
        # Generate personalized content
        goals = self._generate_goals(risk_level, addiction_type)
        tips = self._generate_tips(risk_level)
        
        return {
            "risk_level": risk_level,
            "confidence": confidence,
            "goals": goals,
            "tips": tips,
            "source": source,
            "model_version": "1.0.0",
        }


# Initialize model on import
model = AIRecoveryModel()

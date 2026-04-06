"""
AI Recovery Plan Microservice (Python 3.10 + TensorFlow)
=========================================================
This service runs independently from the main Python 3.14 application.
It provides AI-based personalized recovery plans via REST API.

Architecture:
- FastAPI for REST endpoints
- TensorFlow for deep learning inference
- Scikit-learn models loaded as fallback
- Isolated environment (no dependency on main app)

Author: Senior ML Engineer
Date: December 31, 2025
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Literal
import uvicorn
import logging

from ai_service.model import AIRecoveryModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AI Recovery Plan Service",
    description="AI-powered personalized recovery plan generation using TensorFlow",
    version="1.0.0"
)

# Add CORS middleware for cross-origin requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize AI model (loaded once at startup)
ai_model = None

# ============================================================================
# REQUEST/RESPONSE SCHEMAS
# ============================================================================

class RecoveryPlanRequest(BaseModel):
    """Input schema for recovery plan generation"""
    addiction_type: str = Field(..., description="Type of addiction (alcohol, smoking, gaming, etc.)")
    daily_usage: float = Field(..., ge=0, description="Average daily usage in minutes")
    mood_score: float = Field(..., ge=0, le=10, description="Average mood score (0-10 scale)")
    task_completion_rate: float = Field(..., ge=0, le=1, description="Task completion rate (0.0-1.0)")
    relapse_count: int = Field(..., ge=0, description="Number of relapses in last 30 days")
    
    class Config:
        schema_extra = {
            "example": {
                "addiction_type": "alcohol",
                "daily_usage": 60.0,
                "mood_score": 5.0,
                "task_completion_rate": 0.6,
                "relapse_count": 2
            }
        }


class RecoveryPlanResponse(BaseModel):
    """Output schema for recovery plan"""
    risk_level: Literal["low", "medium", "high"] = Field(..., description="AI-predicted risk level")
    confidence: float = Field(..., ge=0, le=1, description="Model confidence score (0.0-1.0)")
    goals: List[str] = Field(..., description="Personalized recovery goals")
    tips: List[str] = Field(..., description="Actionable tips and recommendations")
    source: Literal["ai", "fallback"] = Field(..., description="Source of prediction")
    model_version: str = Field(..., description="AI model version used")
    
    class Config:
        schema_extra = {
            "example": {
                "risk_level": "medium",
                "confidence": 0.85,
                "goals": [
                    "Complete daily mood check-in",
                    "Attend 2 support group meetings this week",
                    "Practice mindfulness for 10 minutes daily"
                ],
                "tips": [
                    "Stay hydrated and maintain sleep schedule",
                    "Identify and avoid trigger situations",
                    "Reach out to support network when feeling urges"
                ],
                "source": "ai",
                "model_version": "1.0.0"
            }
        }


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize AI model on service startup"""
    global ai_model
    try:
        logger.info("Initializing AI Recovery Model...")
        ai_model = AIRecoveryModel()
        logger.info("✓ AI Model initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize AI model: {e}")
        raise


@app.post("/get_recovery_plan", response_model=RecoveryPlanResponse)
async def get_recovery_plan(request: RecoveryPlanRequest):
    """
    Generate AI-based personalized recovery plan
    
    This endpoint:
    1. Accepts user behavioral data
    2. Runs AI inference using TensorFlow
    3. Predicts risk level with confidence score
    4. Generates personalized goals and tips
    5. Returns structured JSON response
    
    Args:
        request: User behavioral data
        
    Returns:
        RecoveryPlanResponse: AI-generated recovery plan
        
    Raises:
        HTTPException: If prediction fails
    """
    try:
        logger.info(f"Received recovery plan request for addiction_type={request.addiction_type}")
        
        # Prepare input data for AI model
        user_data = {
            "addiction_type": request.addiction_type,
            "daily_usage": request.daily_usage,
            "mood_score": request.mood_score,
            "task_completion_rate": request.task_completion_rate,
            "relapse_count": request.relapse_count
        }
        
        # Run AI prediction
        prediction = ai_model.predict(user_data)
        
        logger.info(f"Prediction completed: risk_level={prediction['risk_level']}, "
                   f"confidence={prediction['confidence']:.2f}")
        
        return RecoveryPlanResponse(
            risk_level=prediction["risk_level"],
            confidence=prediction["confidence"],
            goals=prediction["goals"],
            tips=prediction["tips"],
            source=prediction["source"],
            model_version=prediction["model_version"]
        )
        
    except Exception as e:
        logger.error(f"Error generating recovery plan: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate recovery plan: {str(e)}"
        )


@app.get("/health")
async def health_check():
    """
    Health check endpoint
    
    Returns:
        dict: Service health status
    """
    return {
        "status": "healthy",
        "service": "AI Recovery Plan Service",
        "model_loaded": ai_model is not None,
        "version": "1.0.0"
    }


@app.get("/")
async def root():
    """
    Root endpoint with API information
    
    Returns:
        dict: API metadata
    """
    return {
        "service": "AI Recovery Plan Service",
        "version": "1.0.0",
        "description": "TensorFlow-powered personalized recovery plan generation",
        "endpoints": {
            "POST /get_recovery_plan": "Generate AI-based recovery plan",
            "GET /health": "Service health check",
            "GET /docs": "Interactive API documentation"
        },
        "python_version": "3.10",
        "framework": "FastAPI + TensorFlow"
    }


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    """
    Start the AI microservice
    
    Usage:
        python app.py
        
    The service will be available at:
        http://localhost:8000
        
    Interactive docs at:
        http://localhost:8000/docs
    """
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=False,  # Set to True for development
        log_level="info"
    )

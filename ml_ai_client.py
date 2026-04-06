"""
Python 3.14 AI Client - Recovery Plan Integration
================================================
This module integrates with the AI microservice (Python 3.10 + TensorFlow).

CRITICAL: Does NOT import TensorFlow (incompatible with Python 3.14)
- All AI logic runs in separate Python 3.10 microservice
- Communication via REST API only
- Automatic fallback to rule-based if AI service unavailable

Architecture:
    Python 3.14 App → HTTP Request → Python 3.10 AI Service → TensorFlow Model
                   ← HTTP Response ←

Author: Senior Backend Engineer
Date: December 31, 2025
"""
from __future__ import annotations

import json
import logging
from typing import Any, Dict, List, Literal, Optional

# DO NOT import tensorflow, numpy, or any ML libraries here
# This runs in Python 3.14 which doesn't support TensorFlow
import requests

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# AI Service Configuration
AI_SERVICE_URL = "http://localhost:8000/get_recovery_plan"
AI_HEALTH_URL = "http://localhost:8000/health"
REQUEST_TIMEOUT = 5.0  # seconds

RiskLevel = Literal["low", "medium", "high"]


# ============================================================================
# AI SERVICE CLIENT
# ============================================================================

def _call_ai_service(
    *,
    addiction_type: str,
    daily_usage: float,
    mood_score: float,
    task_completion_rate: float,
    relapse_count: int,
    timeout: float = REQUEST_TIMEOUT,
) -> Optional[Dict[str, Any]]:
    """
    Internal function to call AI microservice
    
    Args:
        addiction_type: Type of addiction
        daily_usage: Daily usage in minutes
        mood_score: Mood rating (0-10)
        task_completion_rate: Completion rate (0.0-1.0)
        relapse_count: Number of relapses
        timeout: Request timeout in seconds
        
    Returns:
        AI service response or None if failed
    """
    payload = {
        "addiction_type": addiction_type,
        "daily_usage": daily_usage,
        "mood_score": mood_score,
        "task_completion_rate": task_completion_rate,
        "relapse_count": relapse_count,
    }
    
    try:
        logger.info(f"Calling AI service at {AI_SERVICE_URL}")
        response = requests.post(
            AI_SERVICE_URL, 
            json=payload, 
            timeout=timeout,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        
        result = response.json()
        logger.info(f"AI service response: risk={result.get('risk_level')}, "
                   f"confidence={result.get('confidence', 0):.2f}")
        return result
        
    except requests.Timeout:
        logger.warning(f"AI service timeout after {timeout}s")
        return None
    except requests.ConnectionError:
        logger.warning("AI service unavailable (connection refused)")
        return None
    except requests.RequestException as exc:
        logger.warning(f"AI service request failed: {exc}")
        return None
    except Exception as exc:
        logger.error(f"Unexpected error calling AI service: {exc}")
        return None



# ============================================================================
# RULE-BASED FALLBACK (Emergency Only)
# ============================================================================

def _fallback_rule_based(
    *,
    addiction_type: str,
    daily_usage: float,
    mood_score: float,
    task_completion_rate: float,
    relapse_count: int,
) -> Dict[str, Any]:
    """
    Simple rule-based fallback when AI service unavailable.
    
    WARNING: This is a simplified emergency fallback only.
    The AI service provides much better personalized recommendations.
    """
    # Simple scoring algorithm
    score = 0.0
    score += (daily_usage / 120.0) * 0.3  # Usage factor
    score += (1.0 - mood_score / 10.0) * 0.2  # Mood factor (inverted)
    score += (1.0 - task_completion_rate) * 0.2  # Task factor (inverted)
    score += min(relapse_count / 5.0, 1.0) * 0.3  # Relapse factor
    
    # Determine risk level
    if score < 0.33:
        risk_level: RiskLevel = "low"
        num_goals = 4
    elif score < 0.66:
        risk_level = "medium"
        num_goals = 5
    else:
        risk_level = "high"
        num_goals = 6
    
    # Generate generic goals
    all_goals = [
        f"Reduce {addiction_type} usage by 10% this week",
        "Complete all daily recovery tasks",
        "Improve mood score to 7+",
        "Build a support network",
        "Practice mindfulness daily",
        "Exercise 3 times per week",
    ]
    goals = all_goals[:num_goals]
    
    # Generate generic tips
    tips = [
        "Track your progress daily",
        "Join a support group",
        "Practice stress management techniques",
    ]
    
    return {
        "risk_level": risk_level,
        "confidence": 0.5,  # Low confidence for rule-based
        "goals": goals,
        "tips": tips,
        "source": "rule-based",
        "model_version": "fallback-1.0",
    }


# ============================================================================
# HEALTH CHECK
# ============================================================================

def check_ai_service_health(timeout: float = 2.0) -> bool:
    """
    Check if AI service is running and healthy.
    
    Returns:
        True if service is healthy, False otherwise
    """
    try:
        response = requests.get(AI_HEALTH_URL, timeout=timeout)
        response.raise_for_status()
        data = response.json()
        return data.get("status") == "healthy"
    except Exception:
        return False


# ============================================================================
# PUBLIC API
# ============================================================================

def get_recovery_plan(
    *,
    addiction_type: str,
    daily_usage: float,
    mood_score: float,
    task_completion_rate: float,
    relapse_count: int,
    force_fallback: bool = False,
) -> Dict[str, Any]:
    """
    Get personalized recovery plan from AI service with automatic fallback.
    
    This is the main entry point for getting AI-powered recovery plans.
    It automatically handles service unavailability with graceful degradation.
    
    Args:
        addiction_type: Type of addiction (e.g., "alcohol", "social_media")
        daily_usage: Daily usage in minutes (0-120)
        mood_score: Mood rating from 0-10 (higher is better)
        task_completion_rate: Task completion rate (0.0-1.0)
        relapse_count: Number of relapses (0+)
        force_fallback: Force use of rule-based fallback (for testing)
        
    Returns:
        Dictionary with recovery plan details
        
    Example:
        >>> plan = get_recovery_plan(
        ...     addiction_type="social_media",
        ...     daily_usage=80,
        ...     mood_score=6,
        ...     task_completion_rate=0.7,
        ...     relapse_count=1
        ... )
    """
    # Input validation
    if not 0 <= mood_score <= 10:
        raise ValueError(f"mood_score must be 0-10, got {mood_score}")
    if not 0 <= task_completion_rate <= 1:
        raise ValueError(f"task_completion_rate must be 0-1, got {task_completion_rate}")
    if daily_usage < 0:
        raise ValueError(f"daily_usage must be non-negative, got {daily_usage}")
    if relapse_count < 0:
        raise ValueError(f"relapse_count must be non-negative, got {relapse_count}")
    
    # Try AI service first (unless forced fallback)
    if not force_fallback:
        ai_result = _call_ai_service(
            addiction_type=addiction_type,
            daily_usage=daily_usage,
            mood_score=mood_score,
            task_completion_rate=task_completion_rate,
            relapse_count=relapse_count,
        )
        
        if ai_result is not None:
            logger.info(f"Using AI prediction: source={ai_result.get('source')}")
            return ai_result
    
    # Fallback to rule-based
    logger.warning("Using rule-based fallback (AI service unavailable)")
    return _fallback_rule_based(
        addiction_type=addiction_type,
        daily_usage=daily_usage,
        mood_score=mood_score,
        task_completion_rate=task_completion_rate,
        relapse_count=relapse_count,
    )


def format_recovery_plan(plan: Dict[str, Any]) -> str:
    """Format recovery plan as human-readable text."""
    lines = [
        f"Risk Level: {plan['risk_level'].upper()}",
        f"Confidence: {plan['confidence']:.1%}",
        f"Source: {plan['source']} (v{plan['model_version']})",
        "",
        "Goals:",
    ]
    
    for i, goal in enumerate(plan["goals"], 1):
        lines.append(f"  {i}. {goal}")
    
    lines.append("")
    lines.append("Tips:")
    for tip in plan["tips"]:
        lines.append(f"  • {tip}")
    
    return "\n".join(lines)


# ============================================================================
# MAIN (for testing)
# ============================================================================

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    print("AI Recovery Plan Client Test")
    print("=" * 50)
    
    # Check service health
    print(f"\nChecking AI service health...")
    is_healthy = check_ai_service_health()
    print(f"AI Service Status: {'✓ Healthy' if is_healthy else '✗ Unavailable'}")
    
    # Test data
    test_cases = [
        {
            "name": "Low Risk User",
            "data": {
                "addiction_type": "social_media",
                "daily_usage": 30,
                "mood_score": 8,
                "task_completion_rate": 0.9,
                "relapse_count": 0,
            }
        },
        {
            "name": "Medium Risk User",
            "data": {
                "addiction_type": "alcohol",
                "daily_usage": 60,
                "mood_score": 5,
                "task_completion_rate": 0.6,
                "relapse_count": 2,
            }
        },
        {
            "name": "High Risk User",
            "data": {
                "addiction_type": "smoking",
                "daily_usage": 100,
                "mood_score": 3,
                "task_completion_rate": 0.3,
                "relapse_count": 5,
            }
        },
    ]
    
    for case in test_cases:
        print(f"\n{case['name']}")
        print("-" * 50)
        
        try:
            plan = get_recovery_plan(**case["data"])
            print(format_recovery_plan(plan))
        except Exception as e:
            print(f"Error: {e}")
    
    print("\n" + "=" * 50)
    print("Test completed!")

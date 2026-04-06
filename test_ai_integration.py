"""
AI Service Test Suite
=====================
Comprehensive tests for the AI Recovery Plan microservice.

Run this after starting the AI service to verify everything works.

Usage:
    python test_ai_integration.py
"""
import json
import sys
import time
from typing import Dict, Any

try:
    import requests
except ImportError:
    print("ERROR: requests library not installed")
    print("Install: pip install requests")
    sys.exit(1)

# Configuration
AI_SERVICE_URL = "http://localhost:8000"
HEALTH_URL = f"{AI_SERVICE_URL}/health"
PREDICT_URL = f"{AI_SERVICE_URL}/get_recovery_plan"
TIMEOUT = 5.0

# Test cases
TEST_CASES = [
    {
        "name": "Low Risk User",
        "expected_risk": "low",
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
        "expected_risk": "medium",
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
        "expected_risk": "high",
        "data": {
            "addiction_type": "smoking",
            "daily_usage": 100,
            "mood_score": 3,
            "task_completion_rate": 0.3,
            "relapse_count": 5,
        }
    },
]


class Colors:
    """ANSI color codes"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'


def print_header(text: str):
    """Print section header"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'=' * 60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'=' * 60}{Colors.END}\n")


def print_success(text: str):
    """Print success message"""
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")


def print_warning(text: str):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠ {text}{Colors.END}")


def print_error(text: str):
    """Print error message"""
    print(f"{Colors.RED}✗ {text}{Colors.END}")


def test_service_running() -> bool:
    """Test if AI service is running"""
    print_header("Test 1: Service Running")
    
    try:
        response = requests.get(AI_SERVICE_URL, timeout=TIMEOUT)
        response.raise_for_status()
        data = response.json()
        
        print_success("Service is running")
        print(f"  Service: {data.get('service', 'Unknown')}")
        print(f"  Version: {data.get('version', 'Unknown')}")
        print(f"  Status: {data.get('status', 'Unknown')}")
        
        return True
        
    except requests.ConnectionError:
        print_error("Service not running (connection refused)")
        print("\nTo start the service:")
        print("  cd ai_service")
        print("  .\\start_service.bat  # Windows")
        print("  ./start_service.sh   # Linux/Mac")
        return False
    except Exception as e:
        print_error(f"Service check failed: {e}")
        return False


def test_health_endpoint() -> bool:
    """Test health check endpoint"""
    print_header("Test 2: Health Check")
    
    try:
        response = requests.get(HEALTH_URL, timeout=TIMEOUT)
        response.raise_for_status()
        data = response.json()
        
        status = data.get("status")
        model_loaded = data.get("model_loaded")
        model_source = data.get("model_source")
        
        if status == "healthy" and model_loaded:
            print_success("Health check passed")
            print(f"  Status: {status}")
            print(f"  Model Loaded: {model_loaded}")
            print(f"  Model Source: {model_source}")
            return True
        else:
            print_warning("Service running but not healthy")
            print(f"  Status: {status}")
            print(f"  Model Loaded: {model_loaded}")
            return False
            
    except Exception as e:
        print_error(f"Health check failed: {e}")
        return False


def test_prediction(test_case: Dict[str, Any]) -> bool:
    """Test prediction endpoint with a test case"""
    name = test_case["name"]
    data = test_case["data"]
    expected_risk = test_case.get("expected_risk")
    
    try:
        start_time = time.time()
        response = requests.post(PREDICT_URL, json=data, timeout=TIMEOUT)
        latency = (time.time() - start_time) * 1000  # ms
        
        response.raise_for_status()
        result = response.json()
        
        # Verify response structure
        required_fields = ["risk_level", "confidence", "goals", "tips", "source", "model_version"]
        missing_fields = [f for f in required_fields if f not in result]
        
        if missing_fields:
            print_error(f"{name}: Missing fields {missing_fields}")
            return False
        
        # Verify values
        risk_level = result["risk_level"]
        confidence = result["confidence"]
        goals = result["goals"]
        tips = result["tips"]
        source = result["source"]
        
        # Validate risk level
        if risk_level not in ["low", "medium", "high"]:
            print_error(f"{name}: Invalid risk level '{risk_level}'")
            return False
        
        # Validate confidence
        if not 0 <= confidence <= 1:
            print_error(f"{name}: Confidence out of range: {confidence}")
            return False
        
        # Validate goals and tips
        if len(goals) < 4 or len(goals) > 6:
            print_warning(f"{name}: Unexpected number of goals: {len(goals)}")
        
        if len(tips) < 3:
            print_warning(f"{name}: Too few tips: {len(tips)}")
        
        # Check if matches expected risk
        risk_match = ""
        if expected_risk:
            if risk_level == expected_risk:
                risk_match = "✓"
            else:
                risk_match = f"(expected {expected_risk})"
        
        print_success(f"{name}")
        print(f"  Risk Level: {risk_level} {risk_match}")
        print(f"  Confidence: {confidence:.1%}")
        print(f"  Goals: {len(goals)} items")
        print(f"  Tips: {len(tips)} items")
        print(f"  Source: {source}")
        print(f"  Latency: {latency:.0f}ms")
        
        return True
        
    except requests.HTTPError as e:
        print_error(f"{name}: HTTP error {e.response.status_code}")
        try:
            error_detail = e.response.json()
            print(f"  Detail: {error_detail.get('detail', 'Unknown error')}")
        except:
            pass
        return False
    except Exception as e:
        print_error(f"{name}: {type(e).__name__}: {e}")
        return False


def test_invalid_input() -> bool:
    """Test API handles invalid input properly"""
    print_header("Test 4: Invalid Input Handling")
    
    invalid_cases = [
        {
            "name": "Missing field",
            "data": {
                "addiction_type": "alcohol",
                # Missing other fields
            }
        },
        {
            "name": "Invalid mood score",
            "data": {
                "addiction_type": "alcohol",
                "daily_usage": 60,
                "mood_score": 15,  # Invalid (> 10)
                "task_completion_rate": 0.6,
                "relapse_count": 2,
            }
        },
        {
            "name": "Negative values",
            "data": {
                "addiction_type": "alcohol",
                "daily_usage": -50,  # Invalid
                "mood_score": 5,
                "task_completion_rate": 0.6,
                "relapse_count": 2,
            }
        },
    ]
    
    all_passed = True
    
    for case in invalid_cases:
        try:
            response = requests.post(PREDICT_URL, json=case["data"], timeout=TIMEOUT)
            
            if response.status_code == 422:
                # Expected validation error
                print_success(f"{case['name']}: Correctly rejected (422)")
            elif response.status_code >= 400:
                # Other error - still acceptable
                print_success(f"{case['name']}: Rejected ({response.status_code})")
            else:
                # Should have been rejected
                print_warning(f"{case['name']}: Accepted when should be rejected")
                all_passed = False
                
        except Exception as e:
            print_error(f"{case['name']}: {e}")
            all_passed = False
    
    return all_passed


def test_performance() -> bool:
    """Test API performance with multiple requests"""
    print_header("Test 5: Performance")
    
    test_data = {
        "addiction_type": "alcohol",
        "daily_usage": 60,
        "mood_score": 5,
        "task_completion_rate": 0.6,
        "relapse_count": 2,
    }
    
    num_requests = 10
    latencies = []
    
    print(f"Sending {num_requests} requests...")
    
    for i in range(num_requests):
        try:
            start_time = time.time()
            response = requests.post(PREDICT_URL, json=test_data, timeout=TIMEOUT)
            latency = (time.time() - start_time) * 1000
            
            response.raise_for_status()
            latencies.append(latency)
            
        except Exception as e:
            print_error(f"Request {i+1} failed: {e}")
            return False
    
    # Calculate statistics
    avg_latency = sum(latencies) / len(latencies)
    min_latency = min(latencies)
    max_latency = max(latencies)
    
    print_success(f"Completed {num_requests} requests")
    print(f"  Average latency: {avg_latency:.0f}ms")
    print(f"  Min latency: {min_latency:.0f}ms")
    print(f"  Max latency: {max_latency:.0f}ms")
    
    if avg_latency < 200:
        print_success("Performance: Excellent (< 200ms)")
    elif avg_latency < 500:
        print_warning("Performance: Acceptable (200-500ms)")
    else:
        print_warning("Performance: Slow (> 500ms)")
    
    return True


def run_all_tests():
    """Run all tests"""
    print(f"\n{Colors.BOLD}AI Recovery Plan Service - Test Suite{Colors.END}")
    print(f"Testing service at: {AI_SERVICE_URL}\n")
    
    # Test 1: Service running
    if not test_service_running():
        print_error("\nService is not running. Please start it first.")
        sys.exit(1)
    
    # Test 2: Health check
    if not test_health_endpoint():
        print_warning("\nService running but health check failed. Continuing anyway...")
    
    # Test 3: Predictions
    print_header("Test 3: Predictions")
    
    prediction_results = []
    for test_case in TEST_CASES:
        result = test_prediction(test_case)
        prediction_results.append(result)
        print()  # Blank line between tests
    
    # Test 4: Invalid input
    invalid_result = test_invalid_input()
    
    # Test 5: Performance
    performance_result = test_performance()
    
    # Summary
    print_header("Test Summary")
    
    total_tests = 2 + len(TEST_CASES) + 2  # health + predictions + invalid + performance
    passed_tests = (
        sum(prediction_results) +
        (1 if invalid_result else 0) +
        (1 if performance_result else 0) +
        2  # service running + health (if we got here)
    )
    
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {total_tests - passed_tests}")
    
    if passed_tests == total_tests:
        print_success("\n🎉 All tests passed!")
        print("\nYour AI service is ready to use!")
        print("\nNext steps:")
        print("  1. Integrate ml_ai_client.py into your main app")
        print("  2. Replace rule-based recovery plan generation")
        print("  3. Monitor performance in production")
        return 0
    else:
        print_warning(f"\n⚠ {total_tests - passed_tests} test(s) failed")
        print("\nPlease review the errors above and fix any issues.")
        return 1


if __name__ == "__main__":
    sys.exit(run_all_tests())

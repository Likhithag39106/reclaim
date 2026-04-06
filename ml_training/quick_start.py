"""
Quick Start: Complete AI Implementation Pipeline
================================================

This script automates the entire ML pipeline:
1. Extract data from Firestore
2. Train ML models
3. Convert to TFLite
4. Validate results

Run with: python quick_start.py
"""

import subprocess
import sys
import os
from pathlib import Path

def print_header(title):
    """Print formatted section header."""
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60 + "\n")

def run_script(script_name, description):
    """Run a Python script and handle errors."""
    print(f"[Running] {description}...")
    print(f"[Script]  {script_name}\n")
    
    try:
        result = subprocess.run(
            [sys.executable, script_name],
            capture_output=False,
            text=True,
            check=True
        )
        print(f"\n[✓] {description} completed successfully!\n")
        return True
    except subprocess.CalledProcessError as e:
        print(f"\n[✗] {description} failed!")
        print(f"[Error] {e}\n")
        return False
    except FileNotFoundError:
        print(f"\n[✗] Script not found: {script_name}")
        return False

def check_dependencies():
    """Check if required packages are installed."""
    print_header("Checking Dependencies")
    
    required_packages = [
        'tensorflow',
        'scikit-learn',
        'pandas',
        'numpy',
        'joblib',
    ]
    
    missing = []
    
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
            print(f"[✓] {package}")
        except ImportError:
            print(f"[✗] {package} - NOT INSTALLED")
            missing.append(package)
    
    if missing:
        print(f"\n[WARNING] Missing packages: {', '.join(missing)}")
        print(f"\nInstall with:")
        print(f"  pip install -r requirements.txt\n")
        
        response = input("Install now? (y/n): ")
        if response.lower() == 'y':
            print("\n[Installing...]")
            subprocess.run([sys.executable, '-m', 'pip', 'install', '-r', 'requirements.txt'])
        else:
            print("[Skipping] Continuing without installing...")
    else:
        print("\n[✓] All dependencies installed!")
    
    return len(missing) == 0

def main():
    """Main execution function."""
    print_header("AI RECOVERY PLAN - QUICK START")
    print("This script will:")
    print("1. Extract training data from Firestore")
    print("2. Train machine learning models")
    print("3. Convert best model to TensorFlow Lite")
    print("4. Prepare files for Flutter deployment")
    print("\nEstimated time: 5-10 minutes\n")
    
    input("Press Enter to begin...")
    
    # Check dependencies
    if not check_dependencies():
        print("\n[WARNING] Some dependencies missing. Results may vary.")
        response = input("Continue anyway? (y/n): ")
        if response.lower() != 'y':
            print("\n[Exiting] Please install dependencies first.")
            return
    
    # Step 1: Data Extraction
    print_header("Step 1: Data Extraction")
    if not run_script('data_extraction.py', 'Data extraction from Firestore'):
        print("[Note] Likely using synthetic data (Firestore not configured)")
        print("[Action] Continuing with synthetic data for demo...\n")
    
    # Step 2: Model Training
    print_header("Step 2: Model Training")
    if not run_script('train_recovery_plan_model.py', 'ML model training'):
        print("\n[ERROR] Training failed. Cannot continue.")
        return
    
    # Step 3: TFLite Conversion
    print_header("Step 3: TFLite Conversion")
    if not run_script('convert_to_tflite.py', 'TensorFlow Lite conversion'):
        print("\n[ERROR] Conversion failed. Cannot continue.")
        return
    
    # Step 4: Validation
    print_header("Step 4: Validation")
    
    # Check output files
    expected_files = [
        '../assets/models/recovery_plan_classifier.tflite',
        '../assets/models/scaler_params.json',
        '../assets/models/class_mapping.json',
        'models/model_metadata.json',
    ]
    
    print("[Checking] Output files...\n")
    all_present = True
    
    for file_path in expected_files:
        if os.path.exists(file_path):
            size_kb = os.path.getsize(file_path) / 1024
            print(f"[✓] {file_path} ({size_kb:.1f} KB)")
        else:
            print(f"[✗] {file_path} - MISSING")
            all_present = False
    
    if all_present:
        print("\n[✓] All files generated successfully!")
    else:
        print("\n[⚠] Some files missing. Check logs above.")
    
    # Final summary
    print_header("SETUP COMPLETE!")
    
    print("Next steps:")
    print("\n1. Flutter Integration:")
    print("   • Files are in: assets/models/")
    print("   • Update pubspec.yaml to include assets")
    print("   • Run: flutter pub get")
    print("\n2. Test the AI service:")
    print("   • Run: flutter test test/ai_recovery_plan_test.dart")
    print("\n3. Use in your app:")
    print("   • Import: ai_recovery_plan_service.dart")
    print("   • Initialize: await AIRecoveryPlanService().initialize()")
    print("   • Generate plan: await service.generateAIPlan(uid, addiction)")
    print("\n4. Review documentation:")
    print("   • See: AI_IMPLEMENTATION_GUIDE.md")
    print("   • Example: example_input_output.json")
    
    if os.path.exists('models/model_metadata.json'):
        import json
        with open('models/model_metadata.json', 'r') as f:
            metadata = json.load(f)
        
        print("\n5. Model Performance:")
        print(f"   • Best model: {max(metadata['results'], key=lambda k: metadata['results'][k]['accuracy'])}")
        for model, results in metadata['results'].items():
            print(f"   • {model}: {results['accuracy']:.4f} accuracy")
    
    print("\n" + "="*60)
    print("For questions, see AI_IMPLEMENTATION_GUIDE.md")
    print("="*60 + "\n")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[Cancelled] Setup interrupted by user.")
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {e}")
        import traceback
        traceback.print_exc()

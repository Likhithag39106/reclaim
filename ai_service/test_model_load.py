from pathlib import Path

# Test path detection
default_path = Path("model.py").parent / "models"
print(f"Default path: {default_path} - exists: {default_path.exists()}")

nested_path = Path("model.py").parent / "ai_service" / "models"
print(f"Nested path: {nested_path} - exists: {nested_path.exists()}")

# Test what Path(__file__).parent gives us
import model as m
print(f"\nModel file: {m.__file__}")
print(f"Model file parent: {Path(m.__file__).parent}")
print(f"Models at default: {(Path(m.__file__).parent / 'models').exists()}")
print(f"Models at nested: {(Path(m.__file__).parent / 'ai_service' / 'models').exists()}")

# Try loading
print(f"\nActual model source: {m.model.model_source}")
if m.model.lr_model:
    print(f"LR Model loaded: {type(m.model.lr_model).__name__}")

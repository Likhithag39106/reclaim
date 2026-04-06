# Firebase Firestore Rules Deployment Script
# Run this after installing Firebase CLI (npm install -g firebase-tools)

Write-Host "Firebase Firestore Rules Deployment" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""

# Check if Firebase CLI is installed
try {
    $firebaseVersion = firebase --version 2>&1
    Write-Host "✓ Firebase CLI installed: $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Firebase CLI not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Deploying Firestore security rules..." -ForegroundColor Cyan

# Deploy the rules
try {
    firebase deploy --only firestore:rules --project reclaim-1fa7c
    
    Write-Host ""
    Write-Host "✓ Security rules deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Restart your Flutter app" -ForegroundColor White
    Write-Host "2. Sign up or login" -ForegroundColor White
    Write-Host "3. Create tasks/moods - they will now save to Firestore!" -ForegroundColor White
    Write-Host "4. Check Firebase Console to confirm data is stored" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "✗ Deployment failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try these steps:" -ForegroundColor Yellow
    Write-Host "1. Run: firebase login" -ForegroundColor White
    Write-Host "2. Then try deploying again" -ForegroundColor White
    Write-Host ""
    Write-Host "Or deploy manually via Firebase Console:" -ForegroundColor Yellow
    Write-Host "https://console.firebase.google.com/project/reclaim-1fa7c/firestore/rules" -ForegroundColor Cyan
}

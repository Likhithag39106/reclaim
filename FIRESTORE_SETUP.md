# Firebase Firestore Security Rules Setup

## Issue
Firebase was only storing authentication details but not user activity data (tasks, moods, recovery plans, trees) because **Firestore security rules were missing**. By default, Firebase blocks all database operations when no rules are configured.

## Solution
Created `firestore.rules` with proper security configuration.

## Security Rules Overview

The rules ensure:
- ✅ Users must be authenticated to access data
- ✅ Users can only read/write their own data
- ✅ All user data is protected by user ID matching
- ✅ Subcollections (tasks, moods, recovery plans, etc.) inherit user ownership checks

### Protected Collections

**Per-User Data:**
- `/users/{userId}` - User profiles
- `/users/{userId}/tasks/{taskId}` - User tasks
- `/users/{userId}/moods/{moodId}` - Mood entries
- `/users/{userId}/recoveryPlans/{planId}` - Recovery plans
- `/users/{userId}/analytics/{analyticsId}` - Analytics data
- `/users/{userId}/relapseRisks/{riskId}` - Relapse risk assessments
- `/trees/{userId}` - User growth trees

## Deployment Steps

### Option 1: Firebase Console (Easiest)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **reclaim-1fa7c**
3. Click **Firestore Database** in left sidebar
4. Click the **Rules** tab
5. Copy the contents of `firestore.rules` and paste into the editor
6. Click **Publish**

### Option 2: Firebase CLI (Recommended for Production)

**Prerequisites:**
```bash
npm install -g firebase-tools
firebase login
```

**Deploy Rules:**
```bash
# Navigate to project root
cd c:\Users\deeks\reclaim_flutter

# Initialize Firebase (if not done)
firebase init firestore
# Select "Use existing project" → reclaim-1fa7c
# Keep firestore.rules as the rules file
# Skip firestore.indexes.json or use default

# Deploy just the rules
firebase deploy --only firestore:rules

# Or deploy everything
firebase deploy
```

### Option 3: Temporary Test Mode (NOT FOR PRODUCTION)

If you need to test immediately without deploying rules:

1. Go to Firebase Console → Firestore Database → Rules
2. Use this TEMPORARY rule (expires automatically):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 1, 1);
    }
  }
}
```

⚠️ **WARNING:** This allows anyone to read/write your database. Only use for testing!

## Verification

After deploying rules, test in your app:

1. Sign up/Login
2. Create a task
3. Check Firebase Console → Firestore Database
4. You should see:
   - `users/{uid}` document with profile
   - `users/{uid}/tasks/{taskId}` with your task
   - `trees/{uid}` with growth data

## Troubleshooting

**Still seeing permission errors?**

1. **Check user is authenticated:**
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   print('User ID: ${user?.uid}');
   ```

2. **Verify rules deployed:**
   - Firebase Console → Firestore → Rules tab
   - Check "Last updated" timestamp

3. **Check console logs:**
   - Look for `[FirestoreService]` debug messages
   - Verify operations are using correct user ID

4. **Test rules in Firebase Console:**
   - Rules tab → Rules Playground
   - Select operation type (get, create, update, delete)
   - Enter document path: `/users/{yourUid}`
   - Click "Run"

## Current Setup

**Firebase Project:** reclaim-1fa7c  
**Rules File:** `firestore.rules`  
**Config File:** `firebase.json`

## Next Steps

1. Deploy the security rules using one of the options above
2. Restart your Flutter app
3. Sign up or login
4. Create tasks, moods, recovery plans - they will now save to Firestore!
5. Check Firebase Console to confirm data is being stored

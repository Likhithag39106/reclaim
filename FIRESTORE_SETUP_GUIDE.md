# Firestore Setup Guide - RECLAIM Project

## Step 1: Deploy Updated Security Rules

### Option A: Using Firebase CLI (Recommended)

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy rules from your project
cd c:\Users\deeks\reclaim_flutter
firebase deploy --only firestore:rules
```

### Option B: Manual Deploy via Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **reclaim-1fa7c** project
3. Navigate to **Firestore Database → Rules**
4. Copy the contents of `firestore.rules` file (in your project root)
5. Paste into the Firebase Console Rules editor
6. Click **Publish**

---

## Step 2: Create Required Composite Indexes

### Index 1: recoveryPlans collection

1. Go to **Firebase Console → Firestore → Indexes**
2. Click **Create Index**
3. Configure:
   - **Collection ID**: `recoveryPlans`
   - **Query scope**: Collection
   - **Fields** (in order):
     - `addiction` (Ascending)
     - `createdAt` (Descending)
     - `__name__` (Ascending)
4. Click **Create Index**

**Or use this direct link** (replace PROJECT_ID):
```
https://console.firebase.google.com/v1/r/project/reclaim-1fa7c/firestore/indexes?create_composite=ClNwcm9qZWN0cy9yZWNsYWltLTFmYTdjL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9yZWNvdmVyeVBsYW5zL2luZGV4ZXMvXxABGg0KCWFkZGljdGlvbhABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
```

### Index 2: tasks collection

1. Go to **Firebase Console → Firestore → Indexes**
2. Click **Create Index**
3. Configure:
   - **Collection ID**: `tasks`
   - **Query scope**: Collection
   - **Fields** (in order):
     - `addiction` (Ascending)
     - `createdAt` (Descending)
     - `__name__` (Ascending)
4. Click **Create Index**

**Or use this direct link**:
```
https://console.firebase.google.com/v1/r/project/reclaim-1fa7c/firestore/indexes?create_composite=Cktwcm9qZWN0cy9yZWNsYWltLTFmYTdjL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy90YXNrcy9pbmRleGVzL18QARoNCglhZGRpY3Rpb24QARoNCgljcmVhdGVkQXQQAhoMCghfX25hbWVfXxAC
```

---

## Step 3: Verify Changes

After deploying rules and creating indexes (wait ~5 minutes for propagation):

1. Restart your Flutter app:
   ```powershell
   flutter run
   ```

2. Check that errors are gone in the debug console

3. Verify data is loading from Firestore

---

## Updated Security Rules Summary

The new rules allow:
- ✅ Authenticated users to read their own user data
- ✅ Authenticated users to read public collections (recoveryPlans, tasks, usageData)
- ✅ Authenticated users to read/write subcollections under their user document
- ✅ Prevents unauthorized writes to public collections
- ❌ Blocks all unauthenticated access

---

## Troubleshooting

**Still getting permission denied?**
- Ensure user is logged in (check Firebase Authentication)
- Wait 5 minutes for rule changes to propagate
- Clear app cache: `flutter clean`

**Indexes not created?**
- Check Firestore → Indexes page for creation status
- Indexes typically take 5-10 minutes to build

**Need to test rules locally?**
Use Firebase Emulator Suite:
```bash
firebase emulators:start
```

---

## References

- [Firebase Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [Firestore Indexes](https://firebase.google.com/docs/firestore/query-data/index-overview)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

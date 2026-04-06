# Recovery Plan Points Fix

## Issue
When completing tasks in recovery plan, the points were not being added to the user's tree growth.

## Root Cause
The `completeGoal()` method in `RecoveryPlanService` was:
- ✅ Correctly updating `totalPoints` in the recovery plan
- ✅ Saving to Firestore
- ❌ **NOT adding tree growth points** (unlike regular task completion)

## Solution
Added tree growth functionality to recovery plan goal completion:

### Changes Made

**File: `lib/services/recovery_plan_service.dart`**

1. **Modified `completeGoal()` method** (line ~412)
   - Now calls `_addTreeGrowth()` after updating the plan
   - Adds points equal to the goal's point value

2. **Added `_addTreeGrowth()` helper method** (line ~442)
   - Mirrors the implementation from `FirestoreService`
   - Reads current tree data from Firestore
   - Adds the goal points to `totalGrowthPoints`
   - Calculates new `growthLevel` (1 level per 100 points)
   - Updates Firestore with new values
   - Includes debug logging for tracking

### How It Works Now

When a user completes a recovery plan goal:

1. **Recovery Plan Updates:**
   - Goal marked as completed with timestamp
   - Plan's `totalPoints` increased by goal's points value (10-25 points)
   - Updated plan saved to Firestore

2. **Tree Growth Updates:** ⭐ NEW
   - Tree's `totalGrowthPoints` increased by the same points
   - Tree's `growthLevel` recalculated (grows 1 level per 100 points)
   - Visual tree on dashboard reflects the growth

### Example Flow

User completes "Morning Intention" goal (10 points):
- Recovery plan: `totalPoints` 0 → 10 ✅
- Tree: `totalGrowthPoints` 50 → 60, `growthLevel` 0 → 0 ✅
- Next 4 similar goals: Tree reaches 100 points → `growthLevel` 1 🌱

## Testing

1. Launch app on emulator
2. Generate a recovery plan
3. Complete a daily goal by checking the checkbox
4. Verify:
   - ✅ Snackbar shows "+[X] points"
   - ✅ Recovery plan header updates total points
   - ✅ Tree widget on dashboard grows
   - ✅ Console shows debug log: `[RecoveryPlanService] Tree growth updated: X total points (level Y)`

## Files Modified
- `lib/services/recovery_plan_service.dart`

## Build Status
- ✅ No compilation errors
- ⚠️ Only style warnings (prefer_const_constructors) - non-breaking

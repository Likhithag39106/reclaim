"""
Data Extraction Pipeline for AI-Based Recovery Plans
=====================================================

This script extracts user data from Firebase Firestore and converts it into
a structured dataset for machine learning model training.

Features extracted per user:
- Addiction type
- Usage patterns (duration, frequency)
- Task completion history
- Mood tracking data
- Relapse history
- Demographics (optional)

Output: CSV file ready for ML training
"""

import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import json
import os

class FirestoreDataExtractor:
    """
    Extracts and preprocesses user data from Firestore for ML training.
    
    This class handles:
    1. Firebase authentication
    2. Data extraction from multiple collections
    3. Feature engineering
    4. Data cleaning and normalization
    5. Export to CSV/JSON formats
    """
    
    def __init__(self, credentials_path: Optional[str] = None):
        """
        Initialize Firestore connection.
        
        Args:
            credentials_path: Path to Firebase service account JSON file.
                            If None, uses FIREBASE_CREDENTIALS environment variable.
        """
        if not firebase_admin._apps:
            # Initialize Firebase Admin SDK
            if credentials_path:
                cred = credentials.Certificate(credentials_path)
            else:
                # Use environment variable or default credentials
                cred_path = os.getenv('FIREBASE_CREDENTIALS', 'firebase-credentials.json')
                if os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                else:
                    print("[WARNING] No credentials found. Using synthetic data mode.")
                    self.db = None
                    return
            
            firebase_admin.initialize_app(cred)
        
        self.db = firestore.client()
        print("[INFO] Firebase connection initialized")
    
    def extract_user_features(self, uid: str, days_lookback: int = 30) -> Dict:
        """
        Extract all features for a single user.
        
        Args:
            uid: User ID
            days_lookback: Number of days to look back for historical data
            
        Returns:
            Dictionary containing all extracted features
        """
        if self.db is None:
            # Return synthetic data if no Firebase connection
            return self._generate_synthetic_user_data()
        
        try:
            # Get user profile
            user_doc = self.db.collection('users').document(uid).get()
            if not user_doc.exists:
                print(f"[WARNING] User {uid} not found")
                return None
            
            user_data = user_doc.to_dict()
            
            # Calculate date range
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days_lookback)
            
            # Extract features from different collections
            features = {
                'uid': uid,
                'addiction': user_data.get('addictions', ['General'])[0],
                'created_at': user_data.get('createdAt'),
                
                # Usage features
                **self._extract_usage_features(uid, start_date, end_date),
                
                # Task completion features
                **self._extract_task_features(uid, start_date, end_date),
                
                # Mood features
                **self._extract_mood_features(uid, start_date, end_date),
                
                # Relapse features
                **self._extract_relapse_features(uid, start_date, end_date),
                
                # Engagement features
                **self._extract_engagement_features(uid, start_date, end_date),
            }
            
            return features
            
        except Exception as e:
            print(f"[ERROR] Failed to extract features for {uid}: {e}")
            return None
    
    def _extract_usage_features(self, uid: str, start_date: datetime, end_date: datetime) -> Dict:
        """Extract app usage pattern features."""
        try:
            # Get activity sessions from Firestore
            sessions = self.db.collection('users').document(uid)\
                .collection('activity')\
                .where('sessionStart', '>=', start_date)\
                .where('sessionStart', '<=', end_date)\
                .stream()
            
            session_data = [doc.to_dict() for doc in sessions]
            
            if not session_data:
                return {
                    'avg_session_duration_min': 0.0,
                    'total_sessions': 0,
                    'max_session_duration_min': 0.0,
                    'sessions_per_day': 0.0,
                    'late_night_sessions': 0,  # 10 PM - 2 AM
                    'weekend_session_ratio': 0.0,
                }
            
            # Calculate usage metrics
            durations = [s.get('duration', 0) / 60 for s in session_data]  # Convert to minutes
            
            # Late night sessions (22:00 - 02:00)
            late_night = sum(1 for s in session_data 
                           if 22 <= s.get('sessionStart').hour or s.get('sessionStart').hour <= 2)
            
            # Weekend sessions
            weekend_sessions = sum(1 for s in session_data 
                                 if s.get('sessionStart').weekday() in [5, 6])
            weekend_ratio = weekend_sessions / len(session_data) if session_data else 0.0
            
            # Sessions per day
            unique_days = len(set(s.get('sessionStart').date() for s in session_data))
            sessions_per_day = len(session_data) / max(unique_days, 1)
            
            return {
                'avg_session_duration_min': np.mean(durations) if durations else 0.0,
                'total_sessions': len(session_data),
                'max_session_duration_min': max(durations) if durations else 0.0,
                'sessions_per_day': sessions_per_day,
                'late_night_sessions': late_night,
                'weekend_session_ratio': weekend_ratio,
            }
            
        except Exception as e:
            print(f"[WARNING] Usage feature extraction failed: {e}")
            return {
                'avg_session_duration_min': 0.0,
                'total_sessions': 0,
                'max_session_duration_min': 0.0,
                'sessions_per_day': 0.0,
                'late_night_sessions': 0,
                'weekend_session_ratio': 0.0,
            }
    
    def _extract_task_features(self, uid: str, start_date: datetime, end_date: datetime) -> Dict:
        """Extract task completion features."""
        try:
            tasks = self.db.collection('users').document(uid)\
                .collection('tasks')\
                .where('createdAt', '>=', start_date)\
                .where('createdAt', '<=', end_date)\
                .stream()
            
            task_data = [doc.to_dict() for doc in tasks]
            
            if not task_data:
                return {
                    'total_tasks': 0,
                    'completed_tasks': 0,
                    'completion_rate': 0.0,
                    'avg_completion_time_hours': 0.0,
                    'current_streak_days': 0,
                }
            
            completed = [t for t in task_data if t.get('completed', False)]
            
            # Calculate completion rate
            completion_rate = len(completed) / len(task_data) if task_data else 0.0
            
            # Calculate average completion time
            completion_times = []
            for task in completed:
                created = task.get('createdAt')
                completed_at = task.get('completedAt')
                if created and completed_at:
                    diff = (completed_at - created).total_seconds() / 3600  # hours
                    completion_times.append(diff)
            
            avg_completion_time = np.mean(completion_times) if completion_times else 0.0
            
            # Calculate current streak (consecutive days with completed tasks)
            streak = self._calculate_streak([t.get('completedAt') for t in completed if t.get('completedAt')])
            
            return {
                'total_tasks': len(task_data),
                'completed_tasks': len(completed),
                'completion_rate': completion_rate,
                'avg_completion_time_hours': avg_completion_time,
                'current_streak_days': streak,
            }
            
        except Exception as e:
            print(f"[WARNING] Task feature extraction failed: {e}")
            return {
                'total_tasks': 0,
                'completed_tasks': 0,
                'completion_rate': 0.0,
                'avg_completion_time_hours': 0.0,
                'current_streak_days': 0,
            }
    
    def _extract_mood_features(self, uid: str, start_date: datetime, end_date: datetime) -> Dict:
        """Extract mood tracking features."""
        try:
            moods = self.db.collection('users').document(uid)\
                .collection('moods')\
                .where('createdAt', '>=', start_date.isoformat())\
                .where('createdAt', '<=', end_date.isoformat())\
                .stream()
            
            mood_data = [doc.to_dict() for doc in moods]
            
            if not mood_data:
                return {
                    'total_mood_logs': 0,
                    'avg_mood_rating': 3.0,  # Neutral
                    'mood_variance': 0.0,
                    'mood_trend': 'stable',  # stable, improving, declining
                    'trigger_count': 0,
                }
            
            # Extract ratings
            ratings = [m.get('rating', 3) for m in mood_data]
            
            # Calculate statistics
            avg_rating = np.mean(ratings)
            mood_variance = np.var(ratings)
            
            # Determine trend (compare first half vs second half)
            mid_point = len(ratings) // 2
            if mid_point > 0:
                first_half_avg = np.mean(ratings[:mid_point])
                second_half_avg = np.mean(ratings[mid_point:])
                
                if second_half_avg > first_half_avg + 0.5:
                    mood_trend = 'improving'
                elif second_half_avg < first_half_avg - 0.5:
                    mood_trend = 'declining'
                else:
                    mood_trend = 'stable'
            else:
                mood_trend = 'stable'
            
            # Count triggers
            trigger_count = sum(len(m.get('triggers', [])) for m in mood_data)
            
            return {
                'total_mood_logs': len(mood_data),
                'avg_mood_rating': avg_rating,
                'mood_variance': mood_variance,
                'mood_trend': mood_trend,
                'trigger_count': trigger_count,
            }
            
        except Exception as e:
            print(f"[WARNING] Mood feature extraction failed: {e}")
            return {
                'total_mood_logs': 0,
                'avg_mood_rating': 3.0,
                'mood_variance': 0.0,
                'mood_trend': 'stable',
                'trigger_count': 0,
            }
    
    def _extract_relapse_features(self, uid: str, start_date: datetime, end_date: datetime) -> Dict:
        """Extract relapse history features."""
        try:
            # Relapses might be stored in recovery plans or as separate collection
            relapses = self.db.collection('users').document(uid)\
                .collection('relapses')\
                .where('timestamp', '>=', start_date)\
                .where('timestamp', '<=', end_date)\
                .stream()
            
            relapse_data = [doc.to_dict() for doc in relapses]
            
            # Calculate days since last relapse
            if relapse_data:
                timestamps = [r.get('timestamp') for r in relapse_data if r.get('timestamp')]
                if timestamps:
                    last_relapse = max(timestamps)
                    days_since_last = (datetime.now() - last_relapse).days
                else:
                    days_since_last = 365  # Default: no recent relapse
            else:
                days_since_last = 365
            
            return {
                'relapse_count': len(relapse_data),
                'days_since_last_relapse': days_since_last,
                'relapse_frequency': len(relapse_data) / 30.0,  # Per 30 days
            }
            
        except Exception as e:
            print(f"[WARNING] Relapse feature extraction failed: {e}")
            return {
                'relapse_count': 0,
                'days_since_last_relapse': 365,
                'relapse_frequency': 0.0,
            }
    
    def _extract_engagement_features(self, uid: str, start_date: datetime, end_date: datetime) -> Dict:
        """Extract user engagement features."""
        try:
            # Get login events
            logins = self.db.collection('users').document(uid)\
                .collection('analytics').document('logins')\
                .collection('events')\
                .where('timestamp', '>=', start_date)\
                .where('timestamp', '<=', end_date)\
                .stream()
            
            login_data = [doc.to_dict() for doc in logins]
            
            # Calculate engagement metrics
            unique_days = len(set(l.get('timestamp').date() for l in login_data if l.get('timestamp')))
            total_days = (end_date - start_date).days
            engagement_rate = unique_days / total_days if total_days > 0 else 0.0
            
            return {
                'total_logins': len(login_data),
                'unique_active_days': unique_days,
                'engagement_rate': engagement_rate,
            }
            
        except Exception as e:
            print(f"[WARNING] Engagement feature extraction failed: {e}")
            return {
                'total_logins': 0,
                'unique_active_days': 0,
                'engagement_rate': 0.0,
            }
    
    def _calculate_streak(self, dates: List[datetime]) -> int:
        """Calculate consecutive days streak from list of dates."""
        if not dates:
            return 0
        
        # Sort dates
        sorted_dates = sorted([d.date() for d in dates if d])
        
        if not sorted_dates:
            return 0
        
        # Calculate streak from most recent date
        streak = 1
        current_date = sorted_dates[-1]
        
        for i in range(len(sorted_dates) - 2, -1, -1):
            expected_date = current_date - timedelta(days=1)
            if sorted_dates[i] == expected_date:
                streak += 1
                current_date = sorted_dates[i]
            else:
                break
        
        return streak
    
    def _generate_synthetic_user_data(self) -> Dict:
        """Generate synthetic user data for testing when Firebase is unavailable."""
        return {
            'uid': f'synthetic_{np.random.randint(1000, 9999)}',
            'addiction': np.random.choice(['Social Media', 'Gaming', 'Substance', 'Gambling']),
            'created_at': datetime.now() - timedelta(days=np.random.randint(30, 365)),
            
            # Usage features
            'avg_session_duration_min': np.random.uniform(10, 120),
            'total_sessions': np.random.randint(20, 200),
            'max_session_duration_min': np.random.uniform(30, 180),
            'sessions_per_day': np.random.uniform(1, 15),
            'late_night_sessions': np.random.randint(0, 50),
            'weekend_session_ratio': np.random.uniform(0.1, 0.5),
            
            # Task features
            'total_tasks': np.random.randint(10, 100),
            'completed_tasks': np.random.randint(5, 90),
            'completion_rate': np.random.uniform(0.3, 0.95),
            'avg_completion_time_hours': np.random.uniform(1, 48),
            'current_streak_days': np.random.randint(0, 30),
            
            # Mood features
            'total_mood_logs': np.random.randint(5, 60),
            'avg_mood_rating': np.random.uniform(2.0, 4.5),
            'mood_variance': np.random.uniform(0.2, 2.0),
            'mood_trend': np.random.choice(['improving', 'stable', 'declining']),
            'trigger_count': np.random.randint(0, 30),
            
            # Relapse features
            'relapse_count': np.random.randint(0, 10),
            'days_since_last_relapse': np.random.randint(1, 365),
            'relapse_frequency': np.random.uniform(0, 0.5),
            
            # Engagement features
            'total_logins': np.random.randint(10, 100),
            'unique_active_days': np.random.randint(5, 30),
            'engagement_rate': np.random.uniform(0.2, 0.9),
        }
    
    def extract_all_users(self, limit: Optional[int] = None) -> pd.DataFrame:
        """
        Extract features for all users in the database.
        
        Args:
            limit: Maximum number of users to extract (None = all users)
            
        Returns:
            pandas DataFrame with all user features
        """
        if self.db is None:
            print("[INFO] No Firebase connection. Generating synthetic dataset...")
            return self._generate_synthetic_dataset(limit or 500)
        
        try:
            # Get all users
            users_query = self.db.collection('users').stream()
            
            all_features = []
            count = 0
            
            for user_doc in users_query:
                if limit and count >= limit:
                    break
                
                uid = user_doc.id
                features = self.extract_user_features(uid)
                
                if features:
                    all_features.append(features)
                    count += 1
                    
                    if count % 10 == 0:
                        print(f"[PROGRESS] Extracted {count} users...")
            
            df = pd.DataFrame(all_features)
            print(f"[SUCCESS] Extracted {len(df)} users")
            return df
            
        except Exception as e:
            print(f"[ERROR] Failed to extract all users: {e}")
            print("[INFO] Generating synthetic dataset instead...")
            return self._generate_synthetic_dataset(limit or 500)
    
    def _generate_synthetic_dataset(self, num_users: int = 500) -> pd.DataFrame:
        """Generate synthetic dataset for development/testing."""
        print(f"[INFO] Generating {num_users} synthetic users...")
        
        all_users = []
        for i in range(num_users):
            user_data = self._generate_synthetic_user_data()
            all_users.append(user_data)
        
        df = pd.DataFrame(all_users)
        print(f"[SUCCESS] Generated {len(df)} synthetic users")
        return df


def main():
    """Main execution function."""
    print("="*60)
    print("FIRESTORE DATA EXTRACTION PIPELINE")
    print("="*60)
    
    # Initialize extractor
    extractor = FirestoreDataExtractor()
    
    # Extract all users (or generate synthetic data)
    print("\n[Step 1/3] Extracting user data...")
    df = extractor.extract_all_users(limit=500)
    
    print(f"\n[Dataset Info]")
    print(f"  Total users: {len(df)}")
    print(f"  Total features: {len(df.columns)}")
    print(f"\n  Sample features:")
    print(df.head())
    
    # Save to CSV
    print("\n[Step 2/3] Saving to CSV...")
    output_path = 'training_data_raw.csv'
    df.to_csv(output_path, index=False)
    print(f"  Saved to: {output_path}")
    
    # Save feature names for reference
    print("\n[Step 3/3] Saving feature metadata...")
    feature_info = {
        'features': list(df.columns),
        'total_features': len(df.columns),
        'extraction_date': datetime.now().isoformat(),
        'num_users': len(df),
    }
    
    with open('feature_info.json', 'w') as f:
        json.dump(feature_info, f, indent=2)
    
    print(f"  Saved to: feature_info.json")
    
    print("\n" + "="*60)
    print("DATA EXTRACTION COMPLETE!")
    print("="*60)
    print("\nNext steps:")
    print("1. Review the extracted data in 'training_data_raw.csv'")
    print("2. Run preprocessing script to clean and normalize data")
    print("3. Train ML model using preprocessed data")


if __name__ == '__main__':
    main()

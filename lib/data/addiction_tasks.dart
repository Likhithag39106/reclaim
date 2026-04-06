class AddictionTasks {
  static const Map<String, List<Map<String, String>>> tasks = {
    'Phone': [
      {'title': 'Morning Phone-Free', 'description': 'Stay off phone for the first 30 minutes after waking up'},
      {'title': 'Social Media Block', 'description': 'Set 2-hour social media-free block'},
      {'title': 'Study Without Phone', 'description': 'Keep phone outside reach while studying'},
      {'title': 'Breathing Over Scrolling', 'description': 'Replace 10 minutes of scrolling with deep breathing'},
      {'title': 'App Detox', 'description': 'Uninstall one distracting app for 24 hours'},
      {'title': 'Read Instead', 'description': 'Read 5 pages of a book instead of scrolling'},
      {'title': 'Reduce Screen Time', 'description': 'Track screen time and aim to reduce by 10%'},
    ],
    'Gaming': [
      {'title': 'Morning Gaming Break', 'description': '1-hour no-gaming window every morning'},
      {'title': 'Walk Instead of Game', 'description': 'Replace one gaming session with a walk'},
      {'title': 'Watch Motivation', 'description': 'Watch 1 motivational video on discipline'},
      {'title': 'Time Limit Gaming', 'description': 'Limit gaming to fixed slots (e.g., 1 hr max)'},
      {'title': 'Gaming Feelings Journal', 'description': 'Write 3 feelings you experience before gaming'},
      {'title': 'Productive First', 'description': 'Do one productive activity before starting gaming'},
      {'title': 'Device Distance', 'description': 'Keep gaming devices in another room for 1 hour'},
    ],
    'Social Media': [
      {'title': 'Breakfast Before Social', 'description': 'No social media until after breakfast'},
      {'title': 'Essential Use Only', 'description': 'Use phone only for messaging or calls for 1 hour'},
      {'title': 'No Posting Day', 'description': 'Post nothing for a full day'},
      {'title': 'Educational Follow', 'description': 'Follow 1 educational page only'},
      {'title': 'Mute Distractions', 'description': 'Mute 5 distracting accounts'},
      {'title': 'Mindful Scrolling', 'description': 'Practice mindful scrolling for 5 minutes'},
      {'title': 'Emotion Tracking', 'description': 'Track emotional state before/after social media'},
    ],
    'Food': [
      {'title': 'Fruit Over Sugar', 'description': 'Replace one sugary snack with fruit'},
      {'title': 'Morning Hydration', 'description': 'Drink 2 full glasses of water in morning'},
      {'title': 'Homemade Meal', 'description': 'Eat one homemade meal today'},
      {'title': '10-Hour Junk Break', 'description': 'Avoid junk food for 10 hours'},
      {'title': 'Mindful Eating', 'description': 'Do 10-minute mindful eating'},
      {'title': 'Craving Journal', 'description': 'Journal cravings for 3 minutes'},
      {'title': 'Healthy Recipe', 'description': 'Try one healthy recipe'},
    ],
    'Smoking': [
      {'title': 'Delay First Cigarette', 'description': 'Delay first cigarette by 10 minutes'},
      {'title': 'Gum Alternative', 'description': 'Chew gum instead of smoking once'},
      {'title': 'Trigger Journal', 'description': 'Write down the trigger before smoking'},
      {'title': 'Walk Through Craving', 'description': 'Walk for 5 minutes when craving hits'},
      {'title': 'Water Over Smoke', 'description': 'Drink water whenever a craving comes'},
      {'title': 'Reduce Count', 'description': 'Reduce cigarette count by one today'},
      {'title': 'Quit Video', 'description': 'Watch a 2-minute quit-smoking video'},
    ],
    'Alcohol': [
      {'title': 'Skip Drinking Day', 'description': 'Skip one drinking day'},
      {'title': 'Juice Instead', 'description': 'Replace drink with fruit juice'},
      {'title': 'Trigger Awareness', 'description': 'Identify a trigger and write it down'},
      {'title': 'Call Support', 'description': 'Call a supportive friend instead of drinking'},
      {'title': 'Walk Through Urge', 'description': 'Walk 10 minutes during cravings'},
      {'title': 'Set Limit', 'description': 'Set a 2-drink limit'},
      {'title': 'Early Sleep', 'description': 'Sleep early to reduce urge'},
    ],
    'Porn': [
      {'title': 'No Bed Phone', 'description': 'Avoid phone in bed'},
      {'title': 'App Blockers', 'description': 'Put app blockers for 2 hours'},
      {'title': 'Meditation Break', 'description': 'Practice 5-minute meditation'},
      {'title': 'Urge Journal', 'description': 'Journal urges for 2 minutes'},
      {'title': 'Physical Activity', 'description': 'Replace urge with push-ups for 30 secs'},
      {'title': 'Early Sleep', 'description': 'Sleep early'},
      {'title': 'Night Phone Cut-off', 'description': 'No phone after 11 PM'},
    ],
    'Shopping': [
      {'title': '12-Hour Shopping Break', 'description': 'No online shopping for 12 hours'},
      {'title': 'Delay Purchase', 'description': 'Add items to cart but don\'t buy for a day'},
      {'title': 'Track Impulse', 'description': 'Track one impulse buy'},
      {'title': 'Daily Budget', 'description': 'Create a ₹500/day limit'},
      {'title': 'Price Comparison', 'description': 'Compare prices offline before buying'},
      {'title': 'Remove Subscription', 'description': 'Remove one unnecessary subscription'},
      {'title': 'Finance Check', 'description': 'Do a 10-minute finance check'},
    ],
    'Substance': [
      {'title': 'Deep Breathing', 'description': '10 minutes of deep breathing'},
      {'title': 'Reasons to Quit', 'description': 'List 3 reasons to quit'},
      {'title': 'Stay Hydrated', 'description': 'Drink 3L water today'},
      {'title': 'Social Connection', 'description': 'Spend 30 minutes with family/friends'},
      {'title': 'Hobby Time', 'description': 'Keep yourself busy with one hobby'},
      {'title': 'Risk Awareness', 'description': 'Identify one high-risk situation'},
      {'title': 'Clean Environment', 'description': 'Take a picture of a clean environment'},
    ],
  };

  static List<Map<String, String>> getTasksForAddiction(String addiction) {
    return tasks[addiction] ?? [];
  }

  static List<Map<String, String>> getTasksForAddictions(List<String> addictions) {
    final allTasks = <Map<String, String>>[];
    for (final addiction in addictions) {
      allTasks.addAll(getTasksForAddiction(addiction));
    }
    return allTasks;
  }
}
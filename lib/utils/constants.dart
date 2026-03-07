class AppConstants {
  // Collection names
  static const String usersCollection = 'users';
  static const String messesCollection = 'messes';
  static const String roomsCollection = 'rooms';
  static const String bazarEntriesCollection = 'bazarEntries';
  static const String mealEntriesCollection = 'mealEntries';
  static const String messagesCollection = 'messages';
  static const String invitationsCollection = 'invitations';
  static const String monthlySummariesCollection = 'monthlySummaries';

  // Roles
  static const String roleManager = 'manager';
  static const String roleMember = 'member';

  // Mess constraints
  static const int minRooms = 1;
  static const int maxRooms = 50;
  static const int minPeoplePerRoom = 1;
  static const int maxPeoplePerRoom = 20;
  static const int maxMessMembers = 100;
}

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

  // Message types
  static const String messageText = 'text';
  static const String messageImage = 'image';
  static const String messageDocument = 'document';

  // Mess constraints
  static const int minRooms = 2;
  static const int maxRooms = 5;
  static const int minPeoplePerRoom = 1;
  static const int maxPeoplePerRoom = 3;
  static const int maxMessMembers = 10;
}

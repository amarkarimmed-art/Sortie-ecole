/// Singleton / classe statique conservant la session école/surveillant en mémoire vive (RAM).
///
/// Permet un accès immédiat et synchrone aux informations de session
/// (token, userId, schoolId, userName, userRole, branding) pour fiabiliser les requêtes
/// API et WebSockets Reverb, y compris sur Flutter Web lors des rafraîchissements.
class AuthSessionMemory {
  static String? token;
  static String? userId;
  static String? schoolId;
  static String? userName;
  static String? userRole;
  static String? schoolName;
  static String? schoolLogo;

  static void setSession({
    required String? token,
    required String? userId,
    required String? schoolId,
    String? userName,
    String? userRole,
    String? schoolName,
    String? schoolLogo,
  }) {
    AuthSessionMemory.token = token;
    AuthSessionMemory.userId = userId;
    AuthSessionMemory.schoolId = schoolId;
    AuthSessionMemory.userName = userName;
    AuthSessionMemory.userRole = userRole;
    AuthSessionMemory.schoolName = schoolName;
    AuthSessionMemory.schoolLogo = schoolLogo;
  }

  static void clear() {
    token = null;
    userId = null;
    schoolId = null;
    userName = null;
    userRole = null;
    schoolName = null;
    schoolLogo = null;
  }
}

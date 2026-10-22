/// Singleton / classe statique conservant la session parent en mémoire vive (RAM).
///
/// Permet un accès immédiat et synchrone aux informations de session
/// (token, userId, schoolId, branding, childIds) pour fiabiliser les requêtes
/// API et WebSockets, y compris sur Flutter Web.
class AuthSessionMemory {
  static String? token;
  static String? userId;
  static String? schoolId;
  static String? schoolName;
  static String? schoolLogo;
  static List<String> childIds = [];

  static void setSession({
    required String? token,
    required String? userId,
    required String? schoolId,
    String? schoolName,
    String? schoolLogo,
    List<String> childIds = const [],
  }) {
    AuthSessionMemory.token = token;
    AuthSessionMemory.userId = userId;
    AuthSessionMemory.schoolId = schoolId;
    AuthSessionMemory.schoolName = schoolName;
    AuthSessionMemory.schoolLogo = schoolLogo;
    AuthSessionMemory.childIds = childIds;
  }

  static void clear() {
    token = null;
    userId = null;
    schoolId = null;
    schoolName = null;
    schoolLogo = null;
    childIds = [];
  }
}

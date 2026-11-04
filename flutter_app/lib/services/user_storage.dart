import 'auth_service.dart';

String userStorageKey(String guestKey) {
  final user = AuthService.instance.user;
  return user == null ? guestKey : '${guestKey}_user_${user.id}';
}

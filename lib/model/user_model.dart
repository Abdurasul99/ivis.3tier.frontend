class LoginUser {
  int? id;
  String? userId;
  String? email;
  String? name;
  String? phoneNumber;
  String? imageUrl;
  String? state;
  String? role;
  String? accessToken;
  int? expiresDate;
  String? refreshToken;
  int? refreshExpiresDate;

  LoginUser({
    this.id,
    this.userId,
    this.email,
    this.name,
    this.phoneNumber,
    this.imageUrl,
    this.state,
    this.role,
    this.accessToken,
    this.expiresDate,
    this.refreshToken,
    this.refreshExpiresDate,
  });

  factory LoginUser.fromJson(Map<String, dynamic> parsedJson) {
    return LoginUser(
      // 백엔드가 id를 int로 반환하므로 타입 무관하게 처리
      id: parsedJson['id'] is int ? parsedJson['id'] as int : int.tryParse(parsedJson['id']?.toString() ?? "0"),
      userId: parsedJson['userId'],
      email: parsedJson['email'],
      name: parsedJson['name'],
      phoneNumber: parsedJson['phoneNumber'],
      imageUrl: parsedJson['imageUrl'],
      state: parsedJson['state'],
      role: parsedJson['role']?.toString(),
      accessToken: parsedJson['accessToken'],
      expiresDate: parsedJson['expireDate'],
      refreshToken: parsedJson['refreshToken'],
      refreshExpiresDate: parsedJson['refreshExpireDate'],
    );
  }

  @override
  String toString() {
    return 'LoginUser{id: $id, userId: $userId, email: $email, name: $name, phoneNumber: $phoneNumber, imageUrl: $imageUrl, state: $state, role: $role}';
  }
}

class LoginResult {
  String? code;
  String? message;
  String? additionalMessage;
  String? responseTime;
  LoginUser? loginUser;

  LoginResult({
    this.code,
    this.message,
    this.additionalMessage,
    this.responseTime,
    this.loginUser,
  });

  factory LoginResult.fromJson(Map<String, dynamic> parsedJson) {
    final user = parsedJson['body'] == null ? null : LoginUser.fromJson(parsedJson['body']);
    return LoginResult(
      code: parsedJson['code'],
      message: parsedJson['message'],
      additionalMessage: parsedJson['additionalMessage'],
      responseTime: parsedJson['responseTime'],
      loginUser: user,
    );
  }

  @override
  String toString() {
    return 'LoginResult{code: $code, message: $message, loginUser: $loginUser}';
  }
}

class Member {
  int? id;
  String? userId;
  String? email;
  String? name;
  String? phoneNumber;
  String? imageUrl;
  String? state;
  String? role;
  String? createdTs;

  Member({
    this.id,
    this.userId,
    this.email,
    this.name,
    this.phoneNumber,
    this.imageUrl,
    this.state,
    this.role,
    this.createdTs,
  });

  factory Member.fromJson(Map<String, dynamic> parsedJson) {
    return Member(
      id: parsedJson['id'],
      userId: parsedJson['user_id'],
      email: parsedJson['email'],
      name: parsedJson['name'],
      phoneNumber: parsedJson['phone_number'],
      imageUrl: parsedJson['image_url'],
      state: parsedJson['state'],
      role: parsedJson['role']?.toString(),
      createdTs: parsedJson['created_ts'],
    );
  }

  @override
  String toString() {
    return 'Member{id: $id, userId: $userId, email: $email, name: $name, phoneNumber: $phoneNumber, imageUrl: $imageUrl, state: $state, role: $role}';
  }
}

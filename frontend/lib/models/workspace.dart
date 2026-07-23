class Workspace {
  final int id;
  final String name;
  final int ownerId;
  final String role; // current user's role in this workspace

  const Workspace({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.role,
  });

  bool get isOwner => role == 'owner';

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as int,
      name: json['name'] as String,
      ownerId: json['owner_id'] as int,
      role: json['role'] as String,
    );
  }
}

class Member {
  final int userId;
  final String email;
  final String name;
  final String role;
  final int membershipId;

  const Member({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.membershipId,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      membershipId: json['membership_id'] as int,
    );
  }
}

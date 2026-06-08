enum AttendanceStatus { hadir, lewat, tidakHadir, mc, ck }

extension AttendanceStatusLabel on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.hadir:
        return 'Hadir';
      case AttendanceStatus.lewat:
        return 'Lewat';
      case AttendanceStatus.tidakHadir:
        return 'TH';
      case AttendanceStatus.mc:
        return 'MC';
      case AttendanceStatus.ck:
        return 'CK';
    }
  }
}

class AttendanceStudent {
  final String id;
  final String name;
  final Map<int, AttendanceStatus> weeklyStatus;

  AttendanceStudent({
    required this.id,
    required this.name,
    Map<int, AttendanceStatus>? weeklyStatus,
    int totalWeeks = 18,
  }) : weeklyStatus = {
          for (var week = 1; week <= totalWeeks; week++)
            week: weeklyStatus?[week] ?? AttendanceStatus.hadir,
        };

  AttendanceStudent copyWith({
    String? id,
    String? name,
    Map<int, AttendanceStatus>? weeklyStatus,
    int totalWeeks = 18,
  }) {
    return AttendanceStudent(
      id: id ?? this.id,
      name: name ?? this.name,
      weeklyStatus: weeklyStatus ?? this.weeklyStatus,
      totalWeeks: totalWeeks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weeklyStatus': weeklyStatus.map(
        (key, value) => MapEntry(key.toString(), value.name),
      ),
    };
  }

  factory AttendanceStudent.fromMap(Map<String, dynamic> map, {int totalWeeks = 18}) {
    final statusMap = map['weeklyStatus'] as Map<String, dynamic>? ?? {};
    final parsedStatus = <int, AttendanceStatus>{};
    statusMap.forEach((key, value) {
      final week = int.tryParse(key);
      if (week != null) {
        parsedStatus[week] = AttendanceStatus.values.firstWhere(
          (e) => e.name == value,
          orElse: () => AttendanceStatus.hadir,
        );
      }
    });

    return AttendanceStudent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      weeklyStatus: parsedStatus,
      totalWeeks: totalWeeks,
    );
  }
}

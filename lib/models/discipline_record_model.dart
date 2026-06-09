import 'package:cloud_firestore/cloud_firestore.dart';

/// Mapping of student IDs to their Matric Numbers and Programs for realism and consistency.
const Map<String, Map<String, String>> studentDetailsMap = {
  's01': {
    'name': 'ADAM HAIQAL BIN ROZLAN',
    'matric': 'A24CS001',
    'program': 'Diploma Sains Komputer (Pembangunan Perisian)'
  },
  's02': {
    'name': 'AHMAD HASNUL ADIB BIN EDHAM',
    'matric': 'A24CS002',
    'program': 'Diploma Sains Komputer (Pembangunan Perisian)'
  },
  's03': {
    'name': 'AIDIEL HAIKAL BIN ZULKARNAIN',
    'matric': 'A24CS003',
    'program': 'Diploma Sains Komputer (Rangkaian)'
  },
  's04': {
    'name': 'AIMAN AIZAT BIN MAHMMED ZUEKFFLEE',
    'matric': 'A24CS004',
    'program': 'Diploma Sains Komputer (Rangkaian)'
  },
  's05': {
    'name': 'AMIR IZZUDDIN BIN YUSRI',
    'matric': 'A24CS005',
    'program': 'Diploma Sains Komputer (Pembangunan Perisian)'
  },
  's06': {
    'name': 'BATRISYAH ALMA BINTI AHMAD SUHAIMI',
    'matric': 'A24IS001',
    'program': 'Diploma Sistem Maklumat'
  },
  's07': {
    'name': 'ELLYSA FARHALIS AZNURIN BINTI AZMI',
    'matric': 'A24IS002',
    'program': 'Diploma Sistem Maklumat'
  },
  's08': {
    'name': 'MARYAM NAQIBAH BINTI HISYAMUDIN',
    'matric': 'A24IS003',
    'program': 'Diploma Sistem Maklumat'
  },
  's09': {
    'name': 'MOHAMMAD JAILANI BIN MOHD NAZIR',
    'matric': 'A24IS004',
    'program': 'Diploma Sistem Maklumat'
  },
  's10': {
    'name': 'MUHAMAMAD AKMAL HAFIZ BIN SHAHARUDDIN',
    'matric': 'A24IT001',
    'program': 'Diploma Teknologi Maklumat'
  },
  's11': {
    'name': 'MUHAMMAD ALIFF AQMAR BIN MOHD KAMAL',
    'matric': 'A24IT002',
    'program': 'Diploma Teknologi Maklumat'
  },
  's12': {
    'name': 'MUHAMMAD AMIRUL AIMAN BIN JUSOH',
    'matric': 'A24IT003',
    'program': 'Diploma Teknologi Maklumat'
  },
  's13': {
    'name': 'MUHAMMAD ARIFF FIKRI BIN MOHD YUNUS',
    'matric': 'A24IT004',
    'program': 'Diploma Teknologi Maklumat'
  },
  's14': {
    'name': 'MUHAMMAD HAFIZ DANIAL BIN ROSLI',
    'matric': 'A24CS006',
    'program': 'Diploma Sains Komputer (Pembangunan Perisian)'
  },
  's15': {
    'name': 'MUHAMMAD HAIKAL SIAAHAAN BIN AMRAN',
    'matric': 'A24CS007',
    'program': 'Diploma Sains Komputer (Pembangunan Perisian)'
  },
  's16': {
    'name': 'MUHAMMAD SYAUQI IQBAL BIN KHALID',
    'matric': 'A24CS008',
    'program': 'Diploma Sains Komputer (Rangkaian)'
  },
  's17': {
    'name': 'MUHAMMAD ZAIREEN SHAH BIN ZAILANI',
    'matric': 'A24CS009',
    'program': 'Diploma Sains Komputer (Rangkaian)'
  },
  's18': {
    'name': 'MUHAMMAD ZAIRUL AMIRUL BIN ZAINUDDIN',
    'matric': 'A24IS005',
    'program': 'Diploma Sistem Maklumat'
  },
  's19': {
    'name': 'WAN MUHAMMAD AIZACK BIN WAN MOHD ASRI',
    'matric': 'A24IS006',
    'program': 'Diploma Sistem Maklumat'
  },
};

class DisciplineRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String matricNo;
  final String programme;
  final String category; // Isu Kehadiran, Salah Laku Tingkah Laku, Isu Akademik, Pelanggaran Kod Pakaian, Lain-lain
  final String title;
  final String description;
  final DateTime reportedDate;
  final String severity; // Rendah, Sederhana, Tinggi
  final String status; // Belum Selesai, Selesai
  final String reportedBy;
  final bool isAutoDetected;
  final double? attendancePercentage;
  final String? catatan; // Remarks/notes by lecturer or admin

  DisciplineRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.matricNo,
    required this.programme,
    required this.category,
    required this.title,
    required this.description,
    required this.reportedDate,
    required this.severity,
    required this.status,
    required this.reportedBy,
    this.isAutoDetected = false,
    this.attendancePercentage,
    this.catatan,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'matricNo': matricNo,
      'programme': programme,
      'category': category,
      'title': title,
      'description': description,
      'reportedDate': Timestamp.fromDate(reportedDate),
      'severity': severity,
      'status': status,
      'reportedBy': reportedBy,
      'isAutoDetected': isAutoDetected,
      'attendancePercentage': attendancePercentage,
      if (catatan != null) 'catatan': catatan,
    };
  }

  factory DisciplineRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime date;
    if (data['reportedDate'] is Timestamp) {
      date = (data['reportedDate'] as Timestamp).toDate();
    } else if (data['reportedDate'] is String) {
      date = DateTime.tryParse(data['reportedDate'] as String) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return DisciplineRecord(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      matricNo: data['matricNo'] ?? '',
      programme: data['programme'] ?? '',
      category: data['category'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      reportedDate: date,
      severity: data['severity'] ?? 'Rendah',
      status: data['status'] ?? 'Belum Selesai',
      reportedBy: data['reportedBy'] ?? '',
      isAutoDetected: data['isAutoDetected'] ?? false,
      attendancePercentage: data['attendancePercentage'] != null
          ? (data['attendancePercentage'] as num).toDouble()
          : null,
      catatan: data['catatan'] as String?,
    );
  }

  DisciplineRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? matricNo,
    String? programme,
    String? category,
    String? title,
    String? description,
    DateTime? reportedDate,
    String? severity,
    String? status,
    String? reportedBy,
    bool? isAutoDetected,
    double? attendancePercentage,
    String? catatan,
    bool clearCatatan = false,
  }) {
    return DisciplineRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      matricNo: matricNo ?? this.matricNo,
      programme: programme ?? this.programme,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      reportedDate: reportedDate ?? this.reportedDate,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      reportedBy: reportedBy ?? this.reportedBy,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      catatan: clearCatatan ? null : (catatan ?? this.catatan),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/discipline_record_model.dart';
import '../models/course_model.dart';
import 'attendance_controller.dart';

class DisciplineController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'discipline_records';

  List<DisciplineRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  // Holds an optional selected discipline record id requested by other views
  // (e.g. Notifikasi view). When set, IsuDisiplinView will auto-expand the
  // corresponding student group to reveal the record.
  String? selectedRecordId;

  /// Request that the IsuDisiplin view open/expand the provided record id.
  void selectRecord(String? id) {
    selectedRecordId = id;
    notifyListeners();
  }

  DisciplineController() {
    loadRecords();
  }

  List<DisciplineRecord> get records => List.unmodifiable(_records);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecords() async {
    _isLoading = true;
    _error = null;
    try {
      final snap = await _db.collection(_collection).orderBy('reportedDate', descending: true).get();
      _records = snap.docs.map(DisciplineRecord.fromFirestore).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error loading discipline records: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addRecord(DisciplineRecord record) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Preserve the provided id (e.g. auto_<studentId>_<courseId>) or generate a new UUID
      final id = record.id.isNotEmpty ? record.id : const Uuid().v4();
      final finalRecord = record.copyWith(id: id);
      await _db.collection(_collection).doc(id).set(finalRecord.toMap());
      // Remove any existing entry with the same id before inserting
      _records.removeWhere((r) => r.id == id);
      _records.insert(0, finalRecord);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateRecord(DisciplineRecord record) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection(_collection).doc(record.id).set(record.toMap());
      final idx = _records.indexWhere((r) => r.id == record.id);
      if (idx != -1) {
        _records[idx] = record;
      } else {
        // Auto-detected record being saved for first time via edit
        _records.insert(0, record);
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteRecord(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (id.startsWith('auto_')) {
        // For auto-detected records: mark as 'Dipadam' in Firestore so it won't
        // be dynamically re-generated on next getCombinedRecords call.
        final parts = id.split('_');
        final studentId = parts.length > 1 ? parts[1] : '';
        final existing = _records.firstWhere(
          (r) => r.id == id,
          orElse: () => DisciplineRecord(
            id: id,
            studentId: studentId,
            studentName: studentDetailsMap[studentId]?['name'] ?? '',
            matricNo: studentDetailsMap[studentId]?['matric'] ?? '',
            programme: studentDetailsMap[studentId]?['program'] ?? '',
            category: 'Isu Kehadiran',
            title: 'Kehadiran Rendah (< 80%)',
            description: '',
            reportedDate: DateTime.now(),
            severity: 'Tinggi',
            status: 'Dipadam',
            reportedBy: 'Sistem',
            isAutoDetected: true,
          ),
        );
        final tombstone = existing.copyWith(status: 'Dipadam');
        await _db.collection(_collection).doc(id).set(tombstone.toMap());
        final idx = _records.indexWhere((r) => r.id == id);
        if (idx != -1) {
          _records[idx] = tombstone;
        } else {
          _records.add(tombstone);
        }
      } else {
        await _db.collection(_collection).doc(id).delete();
        _records.removeWhere((r) => r.id == id);
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateStatus(String id, String newStatus) async {
    _isLoading = true;
    notifyListeners();
    try {
      // For auto-detected records that don't exist in Firestore yet,
      // we need a full document set rather than merge.
      final existing = _records.where((r) => r.id == id).toList();
      if (existing.isEmpty && id.startsWith('auto_')) {
        // Will be handled silently — the record is purely dynamic, update local only
        // (no Firestore doc exists yet, merge would create empty doc)
        debugPrint('updateStatus: auto-detected record $id not persisted yet, skipping Firestore write.');
      } else {
        await _db.collection(_collection).doc(id).set({
          'status': newStatus,
        }, SetOptions(merge: true));
      }

      final idx = _records.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _records[idx] = _records[idx].copyWith(status: newStatus);
      } else {
        await loadRecords();
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculates dynamic auto-detected attendance issues
  /// and returns them merged with manual records.
  List<DisciplineRecord> getCombinedRecords(List<CourseModel> courses, AttendanceController attendanceCtrl) {
    final List<DisciplineRecord> combined = [];
    for (final r in _records) {
      if (r.status != 'Dipadam') {
        combined.add(r);
      }
    }
    // Sort all records: latest report date first
    combined.sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
    return combined;
  }

  Future<String?> addOrUpdateAttendanceWarning({
    required String studentId,
    required String studentName,
    required String matricNo,
    required String programme,
    required String courseId,
    required String courseCode,
    required String courseName,
    required double attendancePercentage,
    required int warningLevel, // 1,2,3 corresponding to thresholds
    String? actingLecturerId,
    String? actingLecturerEmail,
    String? actingLecturerName,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final autoId = 'auto_${studentId}_$courseId';
      const severity = 'Tinggi';
      const status = 'Belum Selesai';
      const reportedBy = 'Sistem';

      // Determine warning label
      String warningLabel;
      switch (warningLevel) {
        case 1:
          warningLabel = 'Amaran Pertama';
          break;
        case 2:
          warningLabel = 'Amaran Kedua';
          break;
        case 3:
        default:
          warningLabel = 'Amaran Ketiga';
      }

      final title = '$warningLabel Kehadiran (${attendancePercentage.toStringAsFixed(1)}%)';

      debugPrint('Discipline: addOrUpdateAttendanceWarning start: student=$studentId course=$courseId pct=${attendancePercentage.toStringAsFixed(1)} level=$warningLevel');

      // Check for existing stored record
      final idx = _records.indexWhere((r) => r.id == autoId);
      if (idx != -1) {
        // Update existing record
        final existing = _records[idx];
        final updated = existing.copyWith(
          studentName: studentName,
          matricNo: matricNo,
          programme: programme,
          category: 'Isu Kehadiran',
          title: title,
          description: 'Kehadiran pelajar telah mencapai ${attendancePercentage.toStringAsFixed(1)}%. Sistem telah menjana $warningLabel secara automatik bagi kursus $courseCode ($courseName).',
          reportedDate: DateTime.now(),
          severity: severity,
          status: status,
          reportedBy: reportedBy,
          isAutoDetected: true,
          attendancePercentage: attendancePercentage,
        );
        await _db.collection(_collection).doc(autoId).set(updated.toMap());
        _records[idx] = updated;
        debugPrint('Discipline: updated auto-record $autoId');
      } else {
        // Create new record
        final rec = DisciplineRecord(
          id: autoId,
          studentId: studentId,
          studentName: studentName,
          matricNo: matricNo,
          programme: programme,
          category: 'Isu Kehadiran',
          title: title,
          description: 'Kehadiran dikesan pada ${attendancePercentage.toStringAsFixed(1)}% dalam kursus $courseCode ($courseName).',
          reportedDate: DateTime.now(),
          severity: severity,
          status: status,
          reportedBy: reportedBy,
          isAutoDetected: true,
          attendancePercentage: attendancePercentage,
        );
        await _db.collection(_collection).doc(autoId).set(rec.toMap());
        _records.removeWhere((r) => r.id == autoId);
        _records.insert(0, rec);
        debugPrint('Discipline: created auto-record $autoId');
      }

      // Build notification and email payloads (recipients added later)
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      final suratAmaran = '''
Surat Amaran Kehadiran

Tarikh: $dateStr

Kepada: $studentName
No. Matrik: $matricNo
Program: $programme

Perkara: $warningLabel - Kehadiran ${attendancePercentage.toStringAsFixed(1)}% dalam kursus $courseCode ($courseName)

Tuan/Puan,

2. Dengan segala hormatnya perkara di atas dirujuk.

3. Berdasarkan rekod kehadiran pelajar ini, peratus kehadiran adalah ${attendancePercentage.toStringAsFixed(1)}%, yang telah mencapai tahap amaran: $warningLabel.

4. Sila ambil tindakan pemantauan dan bimbingan yang sesuai. Sekiranya terdapat alasan sokongan (contingency) sila kemukakan bukti kepada pejabat program untuk pertimbangan.

Sekian, terima kasih.

Yang benar,
Unit Akademik
''';

      // Short notification message required: mention student below Amaran 1/2/3
      final notifMessage = 'Amaran $warningLevel: $studentName (${matricNo}) berada di bawah Amaran $warningLevel (${attendancePercentage.toStringAsFixed(1)}%).';

      final notif = {
        'type': 'kehadiran',
        'studentId': studentId,
        'studentName': studentName,
        'matricNo': matricNo,
        'courseId': courseId,
        'courseCode': courseCode,
        'courseName': courseName,
        'attendancePercentage': attendancePercentage,
        'warningLevel': warningLevel,
        'warningLabel': warningLabel,
        'message': notifMessage,
        'category': 'Isu Kehadiran',
        'disciplineRecordId': autoId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String>[],
        'recipients': <String>[],
        'emailStatus': 'Belum Hantar',
      };

      final email = {
        'subject': 'Surat Amaran Kehadiran: $studentName - $warningLabel',
        'body': suratAmaran,
        'recipients': <String>[],
        'status': 'Belum Hantar',
        'createdAt': FieldValue.serverTimestamp(),
        'disciplineRecordId': autoId,
      };

      // Check if a warning notification already exists for this student, course, and warning level
      final dupSnap = await _db.collection('notifications')
          .where('studentId', isEqualTo: studentId)
          .where('courseId', isEqualTo: courseId)
          .where('warningLevel', isEqualTo: warningLevel)
          .limit(1)
          .get();

      if (dupSnap.docs.isNotEmpty) {
        debugPrint('Discipline: Warning notification already exists for student=$studentId course=$courseId warningLevel=$warningLevel. Skipping.');
        return null;
      }

      // Determine recipients based on warning level
      final List<Map<String, String>> kpUsers = [];
      final List<Map<String, String>> kjUsers = [];
      final List<Map<String, String>> tpaUsers = [];

      final Map<String, String> userNames = {};
      final Map<String, String> userEmails = {};

      // 1) Add acting user if available
      if (actingLecturerId != null && actingLecturerId.isNotEmpty) {
        userNames[actingLecturerId] = actingLecturerName ?? '';
        userEmails[actingLecturerId] = actingLecturerEmail ?? '';
      }

      // 2) Query all Ketua users (role == 'ketuaProgram') and categorize by jawatan
      try {
        final snap = await _db.collection('users').where('role', isEqualTo: 'ketuaProgram').get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final email = data['email'] as String? ?? '';
          final name = (data['name'] ?? data['displayName'] ?? data['fullName'] ?? '').toString();
          final jawatan = data['jawatan'] as String? ?? '';
          if (email.isNotEmpty) {
            userNames[doc.id] = name;
            userEmails[doc.id] = email;
            
            final userMap = {'id': doc.id, 'email': email, 'name': name};
            if (jawatan == 'Ketua Jabatan') {
              kjUsers.add(userMap);
            } else if (jawatan == 'Timbalan Pengarah Akademik') {
              tpaUsers.add(userMap);
            } else {
              kpUsers.add(userMap);
            }
          }
        }
      } catch (_) {}

      // 3) Find course lecturer ID if acting lecturer is not provided or different
      String lecturerId = '';
      if (actingLecturerId != null && actingLecturerId.isNotEmpty) {
        lecturerId = actingLecturerId;
      } else {
        try {
          final courseDoc = await _db.collection('courses').doc(courseId).get();
          if (courseDoc.exists) {
            final cdata = courseDoc.data() ?? {};
            lecturerId = cdata['lecturerId'] as String? ?? '';
          }
        } catch (_) {}
      }

      // Ensure we have name/email for this lecturerId
      if (lecturerId.isNotEmpty && (!userEmails.containsKey(lecturerId) || userEmails[lecturerId]!.isEmpty)) {
        try {
          final udoc = await _db.collection('users').doc(lecturerId).get();
          if (udoc.exists) {
            final udata = udoc.data() ?? {};
            userNames[lecturerId] = (udata['name'] ?? udata['displayName'] ?? udata['fullName'] ?? '').toString();
            userEmails[lecturerId] = udata['email'] as String? ?? '';
          }
        } catch (_) {}
      }

      // 4) Build final recipient list dynamically per warning level
      final List<String> finalRecipientIds = [];
      final List<String> finalRecipientEmails = [];
      final List<String> finalRecipientNames = [];

      void addRecipient(String id) {
        final email = userEmails[id] ?? '';
        final name = userNames[id] ?? '';
        if (id.isNotEmpty && email.isNotEmpty && !finalRecipientIds.contains(id)) {
          finalRecipientIds.add(id);
          finalRecipientEmails.add(email);
          finalRecipientNames.add(name.isNotEmpty ? name : email);
        }
      }

      // Add lecturer (always added)
      if (lecturerId.isNotEmpty) {
        addRecipient(lecturerId);
      }

      // Add Ketua Program (always added for warningLevel >= 1)
      if (warningLevel >= 1) {
        for (final user in kpUsers) {
          addRecipient(user['id']!);
        }
      }

      // Add Ketua Jabatan (added for warningLevel >= 2)
      if (warningLevel >= 2) {
        for (final user in kjUsers) {
          addRecipient(user['id']!);
        }
      }

      // Add Timbalan Pengarah Akademik (added for warningLevel >= 3)
      if (warningLevel >= 3) {
        for (final user in tpaUsers) {
          addRecipient(user['id']!);
        }
      }

      // Update notification and email records with recipients
      final notifWithRecipients = Map<String, dynamic>.from(notif);
      // For UI we store human friendly names in `recipients` and keep ids in `recipientIds`.
      notifWithRecipients['recipients'] = finalRecipientNames;
      notifWithRecipients['recipientIds'] = finalRecipientIds;
      // Mark as in-progress: Cloud Function will update to 'Berjaya Dihantar' or 'Gagal' after send
      notifWithRecipients['emailStatus'] = 'Dalam Proses';
      final notifRef = await _db.collection('notifications').add(notifWithRecipients);
      debugPrint('Discipline: notification written ${notifRef.id} with ${finalRecipientIds.length} recipients');

      final emailWithRecipients = Map<String, dynamic>.from(email);
      emailWithRecipients['recipients'] = finalRecipientEmails;
      emailWithRecipients['status'] = 'Dalam Proses';
      // keep recipientIds in email_history as well for traceability
      emailWithRecipients['recipientIds'] = finalRecipientIds;
      final emailRef = await _db.collection('email_history').add(emailWithRecipients);
      debugPrint('Discipline: email_history written ${emailRef.id} with ${finalRecipientEmails.length} recipients');

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

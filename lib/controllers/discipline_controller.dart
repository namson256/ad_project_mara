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
      final title = 'Kehadiran Rendah (${attendancePercentage.toStringAsFixed(1)}%)';
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
          description: 'Kehadiran dikesan pada ${attendancePercentage.toStringAsFixed(1)}% dalam kursus $courseCode ($courseName).',
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

      // Determine recipients based on warning level
      final List<String> recipientIds = [];
      final List<String> recipientEmails = [];

      // track lecturerId so we can ensure inclusion later
      String lecturerId = '';

      // 1) Lecturer of the course (if available in courses collection)
      try {
        final courseDoc = await _db.collection('courses').doc(courseId).get();
        if (courseDoc.exists) {
          final cdata = courseDoc.data() ?? {};
          final fetchedLecturerId = cdata['lecturerId'] as String? ?? '';
          // Prefer acting lecturer (person who is logged in and changed attendance)
          lecturerId = (actingLecturerId != null && actingLecturerId.isNotEmpty) ? actingLecturerId : fetchedLecturerId;
          if (lecturerId.isNotEmpty) {
            // If acting lecturer email provided and id matches acting id, prefer that email
            String uemail = '';
            if (actingLecturerId != null && actingLecturerId == lecturerId && actingLecturerEmail != null && actingLecturerEmail.isNotEmpty) {
              uemail = actingLecturerEmail;
            } else {
              final udoc = await _db.collection('users').doc(lecturerId).get();
              if (udoc.exists) {
                final udata = udoc.data() ?? {};
                uemail = udata['email'] as String? ?? '';
              }
            }
            if (uemail.isNotEmpty) {
              recipientIds.add(lecturerId);
              recipientEmails.add(uemail);
            }
          }
        }
      } catch (_) {}

      // 2) Ketua Program (all users with role == 'ketuaProgram')
      final List<String> ketuaProgramIds = [];
      try {
        final ketuaSnap = await _db.collection('users').where('role', isEqualTo: 'ketuaProgram').get();
        for (final d in ketuaSnap.docs) {
          final data = d.data();
          final uemail = data['email'] as String? ?? '';
          if (uemail.isNotEmpty && !recipientIds.contains(d.id)) {
            recipientIds.add(d.id);
            recipientEmails.add(uemail);
            ketuaProgramIds.add(d.id);
          }
        }
      } catch (_) {}

      // 3) Ketua Jabatan — look for users with 'jawatan' == 'Ketua Jabatan'
      final List<String> kjIds = [];
      try {
        final kjSnap = await _db.collection('users').where('jawatan', isEqualTo: 'Ketua Jabatan').get();
        for (final d in kjSnap.docs) {
          final data = d.data();
          final uemail = data['email'] as String? ?? '';
          if (uemail.isNotEmpty && !recipientIds.contains(d.id)) {
            recipientIds.add(d.id);
            recipientEmails.add(uemail);
            kjIds.add(d.id);
          }
        }
      } catch (_) {}

      // 4) Timbalan Pengarah Akademik — look for users with 'jawatan' == 'Timbalan Pengarah Akademik'
      final List<String> tpaIds = [];
      try {
        final tpaSnap = await _db.collection('users').where('jawatan', isEqualTo: 'Timbalan Pengarah Akademik').get();
        for (final d in tpaSnap.docs) {
          final data = d.data();
          final uemail = data['email'] as String? ?? '';
          if (uemail.isNotEmpty && !recipientIds.contains(d.id)) {
            recipientIds.add(d.id);
            recipientEmails.add(uemail);
            tpaIds.add(d.id);
          }
        }
      } catch (_) {}

      // Trim recipients according to warning level: 1 -> lecturer + ketuaProgram
      // 2 -> + Ketua Jabatan, 3 -> + Timbalan Pengarah Akademik
      final List<String> finalRecipientIds = [];
      final List<String> finalRecipientEmails = [];

      for (var i = 0; i < recipientIds.length; i++) {
        final id = recipientIds[i];
        final emailAddr = recipientEmails[i];
        if (warningLevel == 1) {
          if (i == 0 || ketuaProgramIds.contains(id)) {
            finalRecipientIds.add(id);
            finalRecipientEmails.add(emailAddr);
          }
        } else if (warningLevel == 2) {
          // include lecturer (index 0), ketuaProgram (collected), and ketua jabatan
          if (i == 0 || ketuaProgramIds.contains(id) || kjIds.contains(id)) {
            finalRecipientIds.add(id);
            finalRecipientEmails.add(emailAddr);
          }
        } else {
          // level 3: include all collected
          finalRecipientIds.add(id);
          finalRecipientEmails.add(emailAddr);
        }
      }

      // Ensure lecturer (acting lecturer) and ketuaProgram recipients are present for warningLevel >= 1
      if (warningLevel >= 1) {
        if (lecturerId.isNotEmpty && !finalRecipientIds.contains(lecturerId)) {
          // try to find lecturer email from recipientEmails, otherwise fetch
          var idx = recipientIds.indexOf(lecturerId);
          String lecEmail = '';
          if (idx != -1) lecEmail = recipientEmails[idx];
          // If acting lecturer email provided, use it
          if (actingLecturerId != null && actingLecturerId == lecturerId && actingLecturerEmail != null && actingLecturerEmail.isNotEmpty) {
            lecEmail = actingLecturerEmail;
          }
          if (lecEmail.isEmpty) {
            try {
              final doc = await _db.collection('users').doc(lecturerId).get();
              if (doc.exists) lecEmail = (doc.data() ?? {})['email'] as String? ?? '';
            } catch (_) {}
          }
          finalRecipientIds.insert(0, lecturerId);
          finalRecipientEmails.insert(0, lecEmail);
        }

        for (final kp in ketuaProgramIds) {
          if (!finalRecipientIds.contains(kp)) {
            var idx = recipientIds.indexOf(kp);
            String kpEmail = '';
            if (idx != -1) kpEmail = recipientEmails[idx];
            if (kpEmail.isEmpty) {
              try {
                final doc = await _db.collection('users').doc(kp).get();
                if (doc.exists) kpEmail = (doc.data() ?? {})['email'] as String? ?? '';
              } catch (_) {}
            }
            finalRecipientIds.add(kp);
            finalRecipientEmails.add(kpEmail);
          }
        }
      }

      // Ensure finalRecipientEmails aligns with finalRecipientIds by resolving any missing emails.
      final Map<String, String> idToEmail = { for (var i = 0; i < recipientIds.length; i++) recipientIds[i]: recipientEmails[i] };
      final List<String> resolvedFinalEmails = [];
      for (final id in finalRecipientIds) {
        String emailAddr = idToEmail[id] ?? '';
        if (emailAddr.isEmpty && id.isNotEmpty) {
          try {
            final doc = await _db.collection('users').doc(id).get();
            if (doc.exists) {
              emailAddr = (doc.data() ?? {})['email'] as String? ?? '';
            }
          } catch (_) {
            // ignore
          }
        }
        // If still empty, skip adding an empty entry to keep recipients clean
        if (emailAddr.isNotEmpty) resolvedFinalEmails.add(emailAddr);
      }

      // Replace finalRecipientEmails with resolved list (keeps order matching finalRecipientIds but only includes addresses we could resolve)
      finalRecipientEmails.clear();
      finalRecipientEmails.addAll(resolvedFinalEmails);

      debugPrint('Discipline: final recipients ids=${finalRecipientIds.join(",")} emails=${finalRecipientEmails.join(",")}');

       // Resolve recipient display names for notification UI. If name not found, fall back to email or id.
       final List<String> finalRecipientNames = [];
       for (var i = 0; i < finalRecipientIds.length; i++) {
         final id = finalRecipientIds[i];
         String displayName = '';
         try {
           if (id.isNotEmpty) {
             final udoc = await _db.collection('users').doc(id).get();
             if (udoc.exists) {
               final udata = udoc.data() ?? {};
               displayName = (udata['displayName'] ?? udata['name'] ?? udata['fullName'] ?? udata['email'] ?? '').toString();
             }
           }
         } catch (_) {
           // ignore
         }
         if (displayName.isEmpty) {
           // fallback to email if available, otherwise keep id
           if (i < finalRecipientEmails.length && finalRecipientEmails[i].isNotEmpty) {
             displayName = finalRecipientEmails[i];
           } else {
             displayName = id;
           }
         }
         finalRecipientNames.add(displayName);
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

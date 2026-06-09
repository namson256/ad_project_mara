# Enhancement Plan: Laporan Module (Modul Pelaporan & Isu Disiplin)

Enhance the "Laporan" module in the portal by splitting it into two distinct pages: **Modul Pelaporan** (reporting dashboard) and **Isu Disiplin** (discipline case management). The implementation will support role-based permissions, auto-detection of attendance below 80%, case grouping by student, and comprehensive Bahasa Melayu terminology.

---

## User Review Required

> [!IMPORTANT]
> **Role-Based Access Guarding:**
> To align with the existing path-based security checks in `AppRouter` (`_guard` method), new paths will be defined per role:
> * **Admin:** `/admin/pelaporan` and `/admin/isu-disiplin`
> * **Pensyarah:** `/lecturer-pelaporan` and `/lecturer-isu-disiplin`
> * **Ketua Program:** `/ketua-pelaporan` and `/ketua-isu-disiplin`
>
> **Role Permissions Mapping:**
> * **Pentadbir (Admin/Staff)** & **Pensyarah:** Full management (View, Add, Edit, Delete, Update Status).
> * **Ketua Program:** View-only (Read-only, no additions, edits, deletions, or status updates).

---

## Proposed Changes

### Database & Models

#### [NEW] [discipline_record_model.dart](file:///c:/Users/Stell/ad_project_mara/lib/models/discipline_record_model.dart)
Create the `DisciplineRecord` model containing details for discipline issues.
* Fields:
  * `id`: unique record ID
  * `studentId`: student ID (e.g., `s01` - `s19`)
  * `studentName`: student full name
  * `matricNo`: matric card number (mapped from `studentId` using a lookup table)
  * `programme`: course/program of study
  * `category`: "Isu Kehadiran" | "Salah Laku Tingkah Laku" | "Isu Akademik" | "Pelanggaran Kod Pakaian" | "Lain-lain"
  * `title`: issue summary title
  * `description`: full report details
  * `reportedDate`: report date/timestamp
  * `severity`: "Rendah" | "Sederhana" | "Tinggi"
  * `status`: "Belum Selesai" | "Selesai"
  * `reportedBy`: name/email of the reporter
  * `isAutoDetected`: flag indicating if the issue was system-detected
  * `attendancePercentage`: optional double for attendance issues

---

### Controllers

#### [NEW] [discipline_controller.dart](file:///c:/Users/Stell/ad_project_mara/lib/controllers/discipline_controller.dart)
Create `DisciplineController` to handle Firestore operations on the `discipline_records` collection and perform real-time auto-detection of students with attendance < 80%.
* Methods:
  * `loadRecords()`: Stream/fetch records from Firestore.
  * `addRecord(DisciplineRecord)`: Create new record in Firestore.
  * `updateRecord(DisciplineRecord)`: Edit an existing record.
  * `deleteRecord(String id)`: Remove a record.
  * `updateStatus(String id, String status)`: Toggle between "Belum Selesai" and "Selesai".
  * `getCombinedRecords(courses, attendanceCtrl)`: Merge Firestore records with live dynamically generated low-attendance warnings labeled "Dikesan Secara Automatik".

#### [MODIFY] [main.dart](file:///c:/Users/Stell/ad_project_mara/lib/main.dart)
Register `DisciplineController` inside the `MultiProvider` configuration.

---

### Routing & Shell Layouts

#### [MODIFY] [app_router.dart](file:///c:/Users/Stell/ad_project_mara/lib/routing/app_router.dart)
Add routes for the two new pages under all three user roles, and update the router guards.
* Admin Routes: `/admin/pelaporan`, `/admin/isu-disiplin`
* Lecturer Routes: `/lecturer-pelaporan`, `/lecturer-isu-disiplin`
* Ketua Program Routes: `/ketua-pelaporan`, `/ketua-isu-disiplin`

#### [MODIFY] [admin_shell.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/admin/admin_shell.dart)
Modify the sidebar items to map to `/admin/pelaporan` and `/admin/isu-disiplin`. Ensure active highlights display correctly for these paths.

#### [MODIFY] [lecturer_shell.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/lecturer/lecturer_shell.dart)
Modify the lecturer sidebar. Replace the single "Laporan" nav item with "Modul Pelaporan" (`/lecturer-pelaporan`) and "Isu Disiplin" (`/lecturer-isu-disiplin`).

#### [NEW] [ketua_shell.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/ketua/ketua_shell.dart)
Create a new `KetuaShell` for the Ketua Program layout so that they have the identical sidebar navigation experience, providing easy toggle between their dashboard, Modul Pelaporan, and Isu Disiplin.

---

### Views

#### [NEW] [pelaporan_view.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/laporan/pelaporan_view.dart)
The Dashboard view containing stats cards and charts for all roles.
* Key stats displayed:
  * Jumlah Pelajar (Total students = 19)
  * Jumlah Kes Disiplin (Total manual + auto-detected cases)
  * Jumlah Pelajar Kehadiran < 80% (Unique count of students below 80% attendance)
  * Jumlah Kes Belum Selesai
  * Jumlah Kes Selesai
* Interactive charts:
  * Category breakdown distribution chart (horizontal progress charts)
  * Case Status and Severity breakdown charts

#### [NEW] [isu_disiplin_view.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/laporan/isu_disiplin_view.dart)
The main Discipline cases view.
* Category filter cards at the top (with counts).
* Search and filters.
* List of students with discipline history (Expandable Student Cards showing matric, program, and total cases).
* Expanded view showing history list sorted by newest report date first.
* Buttons to Add, Edit, Delete, or toggle status of cases.
* Auto-populates student's matric & program when a student is selected in the "Tambah Rekod" form.
* Read-only mode for Ketua Program role.

#### [MODIFY] [ketua_dashboard_view.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/ketua/ketua_dashboard_view.dart)
Modify the dashboard to use the new `KetuaShell` and add quick link buttons to "Pelaporan" and "Isu Disiplin".

#### [MODIFY] [lecturer_dashboard_view.dart](file:///c:/Users/Stell/ad_project_mara/lib/views/lecturer/lecturer_dashboard_view.dart)
Update the quick links on the dashboard to route to `/lecturer-pelaporan` and `/lecturer-isu-disiplin`.

---

## Verification Plan

### Automated Verification
* Run build check: `flutter build web` or `flutter test` to ensure there are no compilation/lint errors.

### Manual Verification
1. Log in as **Pentadbir** (admin/staff). Verify both routes in the sidebar. Attempt to add, edit, update status, and delete a discipline case.
2. Log in as **Pensyarah** (lecturer). Add a record, check that the "Dikesan Secara Automatik" tag works for low-attendance students.
3. Log in as **Ketua Program**. Verify that the page loads correctly but all editing features (Add, Edit, Delete, Change Status) are disabled.
4. Modify student attendance under a course so attendance falls below 80%. Verify that the student automatically appears under "Isu Kehadiran" with the "Dikesan Secara Automatik" label and correct percentage.

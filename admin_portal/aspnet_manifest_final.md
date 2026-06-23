# IRAMS Admin Portal - Final Architecture Manifest

> Generated: 2026-04-30
> Project: ASP.NET Web Forms + Client-Side Firestore (Firebase JS SDK 11.6.1)
> Purpose: Gap analysis against Flutter mobile app

---

## 1. Database Interactions (Firestore)

### Collection: `Users`

| Field | Type | Read By | Written By |
|---|---|---|---|
| FullName | string | Dashboard, Users, UserProfile, UserEdit, Jobs, RecentJobList, UserActivity | UserEdit |
| Email | string | Users, UserProfile, UserEdit, UserActivity | UserEdit |
| PhoneNumber | string | Users, UserProfile, UserEdit, UserActivity | UserEdit |
| UserID | string | Users, UserActivity | -- |
| Status | string | Users, UserProfile, UserEdit, UserActivity | UserProfile (suspend/activate), UserEdit |
| RegistrationDate | timestamp | Users, UserActivity | -- |
| LastLogin | timestamp | Users, UserProfile | -- |
| ProfileImage | string | UserProfile, UserEdit | UserEdit |
| EmergencyName | string | UserProfile, UserEdit | UserEdit |
| EmergencyPhone | string | UserProfile, UserEdit | UserEdit |
| Name | string | Dashboard (fallback), UserActivity (fallback) | -- |

**Operations:**
- `getDocs(collection "Users")` -- Users, UserActivity, Dashboard (count)
- `getDoc(doc "Users/{id}")` -- UserProfile, UserEdit, Dashboard, Jobs, RecentJobList
- `updateDoc` -- UserProfile (Status), UserEdit (FullName, Email, PhoneNumber, EmergencyName, EmergencyPhone, Status, ProfileImage)
- `deleteDoc` -- Users (list view hard delete), UserProfile (profile view hard delete) **[WARNING: still hard-deleting Users]**
- `getCountFromServer` -- Dashboard

---

### Collection: `Contractor`

| Field | Type | Read By | Written By |
|---|---|---|---|
| FullName | string | Dashboard, Contractors, ContractorProfile, ContractorEdit, ComplianceDesk, RevenueReports, ContractorPerformance, FinanceDesk, AssignContractor | ContractorEdit |
| Email | string | Contractors, ContractorProfile, ContractorEdit, ComplianceDesk, FinanceDesk | ContractorEdit |
| PhoneNumber | string | Contractors, ContractorProfile, ContractorEdit, ComplianceDesk, JobDetails | ContractorEdit |
| ContractorID | string | Contractors, FinanceDesk | -- |
| AccountStatus | string | Contractors, ContractorProfile, ContractorEdit, FinanceDesk | Contractors (soft delete), ContractorProfile (soft delete / suspend / activate), ContractorEdit |
| VerificationStatus | string | Contractors, ContractorProfile, ContractorEdit, ComplianceDesk | ContractorProfile (approve/reject), ContractorEdit |
| ServiceTypes | array\|string | Contractors, ContractorProfile, ContractorEdit, AssignContractor | ContractorEdit |
| TotalJobs | string\|number | Contractors | -- |
| LastLogin | timestamp | Contractors, ContractorProfile | -- |
| CompanyName | string | ContractorProfile, ContractorEdit, Dashboard (fallback), RevenueReports, RecentJobList | ContractorEdit |
| CompanyContactPhone | string | ContractorProfile, ContractorEdit | ContractorEdit |
| ProfileImage | string | ContractorEdit | ContractorEdit |
| ApprovedProfileImageUrl | string | ContractorProfile | ContractorProfile (on approve) |
| SubmittedSelfieUrl | string | ContractorProfile | -- |
| ComplianceDocumentsMetadata | map | ContractorProfile | ContractorProfile (approve/reject - sets status, rejectionReason per slug) |
| IsDeleted | boolean | Contractors, FinanceDesk | Contractors (soft delete), ContractorProfile (soft delete) |
| Status | string | AssignContractor | AssignContractor ("Unavailable") |
| isAvailable | boolean | -- | AssignContractor (false) |
| Location | string | AssignContractor | -- |
| Rating | string\|number | AssignContractor, JobDetails | -- |
| Distance | string\|number | AssignContractor | -- |
| CreatedAt | timestamp | ComplianceDesk | -- |
| BankName | string | FinanceDesk | -- |
| BankAccount | string | FinanceDesk | -- |

**Operations:**
- `getDocs(collection "Contractor")` -- Contractors, ContractorPerformance, FinanceDesk, AssignContractor, Dashboard (count)
- `getDocs(query where VerificationStatus == "under_review")` -- ComplianceDesk, Site1.Master (badge)
- `getDoc(doc "Contractor/{id}")` -- ContractorProfile, ContractorEdit, Dashboard, Jobs, JobDetails, RevenueReports, RecentJobList, FinanceDesk
- `updateDoc` -- Contractors (IsDeleted, AccountStatus), ContractorProfile (IsDeleted, AccountStatus, VerificationStatus, ComplianceDocumentsMetadata, ApprovedProfileImageUrl), ContractorEdit (FullName, Email, PhoneNumber, CompanyName, CompanyContactPhone, AccountStatus, VerificationStatus, ServiceTypes, ProfileImage), AssignContractor (Status, isAvailable)
- `getCountFromServer` -- Dashboard

---

### Collection: `Jobs`

| Field | Type | Read By | Written By |
|---|---|---|---|
| JobID | string | Dashboard, Jobs, JobDetails, JobPerformance | -- |
| ServiceType | string | Dashboard, Jobs, JobDetails, UserProfile, ActiveJobList | -- |
| UserLocation | string | Dashboard, Jobs, JobDetails, UserProfile, ActiveJobList | -- |
| DateRequested | timestamp | Jobs, JobDetails, UserProfile | -- |
| Status | string | Dashboard, Jobs, JobDetails, UserProfile, ActiveJobList | AssignContractor ("Assigned") |
| ContractorAssigned | DocumentReference | Dashboard, Jobs, JobDetails, ActiveJobList | AssignContractor (set to Contractor doc ref) |
| UserID | string\|DocumentReference | Jobs, UserProfile | -- |
| TotalCost | number | Jobs, UserProfile | -- |
| PaymentMethod | string | Jobs, UserProfile | -- |
| DateAccepted | timestamp | JobPerformance | -- |
| DateCompleted | timestamp | JobPerformance | -- |

**Operations:**
- `getDocs(collection "Jobs")` -- Jobs, UserProfile (manual filter)
- `getDocs(query where Status != "Completed")` -- Dashboard (active, limit 10), ActiveJobList
- `getDoc(doc "Jobs/{id}")` -- JobDetails, AssignContractor, JobPerformance
- `updateDoc` -- AssignContractor (ContractorAssigned, Status)
- `getCountFromServer` -- Dashboard

---

### Collection: `JobInvoice`

| Field | Type | Read By | Written By |
|---|---|---|---|
| JobID | string | Dashboard, RevenueReports, JobPerformance | -- |
| ServiceType | string | Dashboard, ContractorProfile, RevenueReports, RecentJobList, JobPerformance, ContractorPerformance, UserActivity | -- |
| UserLocation | string | Dashboard, RevenueReports, RecentJobList | -- |
| TotalCost | number | Dashboard, ContractorProfile, RevenueReports, RecentJobList, ContractorPerformance, FinanceDesk | -- |
| PaymentMethod | string | Dashboard, RevenueReports, RecentJobList | -- |
| Status | string | ContractorProfile, ContractorPerformance, JobPerformance, FinanceDesk | -- |
| RequestedTime | timestamp | Dashboard, RecentJobList, JobPerformance, ContractorPerformance, UserActivity | -- |
| ContractorID | string | ContractorProfile, RevenueReports, ContractorPerformance, RecentJobList | -- |
| UserID | string\|DocumentReference | Dashboard, RecentJobList, UserActivity | -- |
| UserRating | number | ContractorPerformance, JobPerformance | -- |
| CompletionTime | timestamp | ContractorPerformance | -- |
| StartTime | timestamp | ContractorPerformance | -- |
| CancellationReason | string | JobPerformance | -- |

**Operations:**
- `getDocs(collection "JobInvoice")` -- RevenueReports (ordered by __name__), RecentJobList (ordered by RequestedTime desc), JobPerformance, UserActivity
- `getDocs(query where ContractorID == {id})` -- ContractorProfile, ContractorPerformance, FinanceDesk
- `getDocs(query where ContractorID == {id} AND Status == "Completed")` -- FinanceDesk (monthly statements)

**Note:** This collection is read-only in the Admin Portal. All writes originate from the Flutter mobile app.

---

### Collection: `Services`

| Field | Type | Read By | Written By |
|---|---|---|---|
| ServiceID | string | Services, ServiceAdd (for next-ID generation) | ServiceAdd |
| ServiceName | string | Services, ServiceEdit, ContractorEdit (checkbox list) | ServiceAdd, ServiceEdit |
| BasePrice | string\|number | Services, ServiceEdit | ServiceAdd, ServiceEdit |
| Description | string | Services, ServiceEdit | ServiceAdd, ServiceEdit |
| Status | string | Services, ServiceEdit | ServiceAdd, ServiceEdit |
| CreatedAt | timestamp | -- | ServiceAdd |

**Operations:**
- `getDocs(collection "Services")` -- Services, ServiceAdd (next-ID calc), ContractorEdit (service type checkboxes), Dashboard (count)
- `getDoc(doc "Services/{id}")` -- ServiceEdit
- `setDoc(doc "Services/{slug}")` -- ServiceAdd (creates new doc with slug-based ID)
- `updateDoc` -- ServiceEdit (ServiceName, BasePrice, Description, Status)
- `deleteDoc` -- Services (hard delete)
- `getCountFromServer` -- Dashboard

---

### Collection: `Withdrawals`

| Field | Type | Read By | Written By |
|---|---|---|---|
| Status | string | FinanceDesk, Site1.Master (badge) | FinanceDesk ("completed") |
| ContractorID | string | FinanceDesk | -- |
| ContractorName | string | FinanceDesk (fallback) | -- |
| ContractorDisplayID | string | FinanceDesk (fallback) | -- |
| BankName | string | FinanceDesk (fallback) | -- |
| BankAccount | string | FinanceDesk (fallback) | -- |
| Amount | number | FinanceDesk | -- |
| RequestedAt | timestamp | FinanceDesk | -- |

**Operations:**
- `getDocs(query where Status == "pending")` -- FinanceDesk, Site1.Master (badge count)
- `updateDoc` -- FinanceDesk (Status to "completed")

---

## 2. External Integrations

| Integration | Location | Purpose |
|---|---|---|
| **Firebase Auth** (Anonymous) | Site1.Master | `signInAnonymously` to authenticate Firestore reads/writes; dispatches `firebase-auth-ready` event |
| **EmailJS** (browser SDK v4) | Site1.Master (CDN + init), FinanceDesk.aspx (send logic) | Sends monthly earnings statements to contractors via `emailjs.send()` |
| **Firebase Storage** | ContractorEdit (imported) | `getStorage`, `ref`, `uploadBytes`, `getDownloadURL` imported but image upload falls back to manual save |
| **ASP.NET Server-Side Auth** | Login.aspx / Login.aspx.cs | Server-side admin login (username/password), session management |
| **ASP.NET WebMethod** | UserEdit.aspx / UserEdit.aspx.cs | `SaveProfileImage` endpoint for base64 image upload to server `images/` folder |

---

## 3. Existing Pages & Functionalities

### Authentication
| Page | Functionality |
|---|---|
| **Login.aspx** | Admin login form (server-side postback to `Login.aspx.cs`). No Firestore interaction. Standalone layout (no master page). |

### Layout
| Page | Functionality |
|---|---|
| **Site1.Master** | Shared layout: sidebar nav (Dashboard, Users, Contractors, Jobs, Reports, Service Management, Compliance Desk, Finance Desk), top navbar with admin name + logout. Initializes Firebase app + anonymous auth. Loads EmailJS SDK. Runs sidebar badge counts for Compliance (under_review contractors) and Finance (pending withdrawals). |

### Dashboard
| Page | Functionality |
|---|---|
| **Dashboard.aspx** | Summary cards: Total Users, Total Contractors, Total Jobs, Total Services (via `getCountFromServer`). Active Jobs table (Jobs where Status != Completed, limit 10, resolves contractor name via DocumentReference). Recent Job Invoices table (JobInvoice ordered by RequestedTime desc, limit 5, resolves User + Contractor names). |

### Users Module
| Page | Functionality |
|---|---|
| **Users.aspx** | Users list table with search (Name, Email, UserID) and sort (Name, ID, Status, Registration, LastLogin). Delete via modal confirmation (**hard delete** with `deleteDoc`). Links to UserProfile. |
| **UserProfile.aspx** | Read-only profile display: FullName, Email, Phone, Status, EmergencyName, EmergencyPhone, ProfileImage. Suspend/Activate toggle (updates Status). Delete button (**hard delete** with `deleteDoc`). Service Requested table (queries all Jobs, matches UserID by string or DocumentReference). Edit link to UserEdit. |
| **UserEdit.aspx** | Edit form: FullName, Email, Phone, EmergencyName, EmergencyPhone, Status dropdown. Profile image upload (base64 sent to server-side WebMethod `SaveProfileImage`, filename stored in Firestore). Saves via `updateDoc`. |

### Contractors Module
| Page | Functionality |
|---|---|
| **Contractors.aspx** | Contractors list table with search (Name, Email, ContractorID) and sort (Name, ID, Status, Verification, Jobs, LastLogin). **Soft delete** via modal (sets IsDeleted: true, AccountStatus: "Deactivated"). Archived contractors show grey "Archived" badge and disabled button. Links to ContractorProfile. |
| **ContractorProfile.aspx** | Read-only profile display: FullName, Email, Phone, ServiceTypes, AccountStatus, CompanyName, CompanyContactPhone, VerificationStatus. Profile image (prefers ApprovedProfileImageUrl, falls back to SubmittedSelfieUrl). Pending Selfie section. Verification Documents grid (renders ComplianceDocumentsMetadata with status badges and lightbox). Approval workflow: Approve (sets VerificationStatus to "approved", all doc statuses to "approved", copies selfie to ApprovedProfileImageUrl) and Reject (with reason modal, sets VerificationStatus to "rejected", all doc statuses to "rejected" with rejectionReason). Suspend/Activate toggle. **Soft delete** (sets IsDeleted: true, AccountStatus: "Deactivated"). Job Invoice table (JobInvoice where ContractorID matches). Edit link to ContractorEdit. |
| **ContractorEdit.aspx** | Edit form: FullName, Email, Phone, ServiceTypes (multi-select checkboxes loaded from Services collection), CompanyName, CompanyContactPhone, AccountStatus, VerificationStatus. Profile image upload (Firebase Storage imported, but falls back to manual). Saves via `updateDoc`. |

### Jobs Module
| Page | Functionality |
|---|---|
| **Jobs.aspx** | Jobs list table with search (JobID, ServiceType, User, Contractor, Location, Status) and sort (date asc/desc, status). Resolves UserID (string or DocumentReference) to FullName. Resolves ContractorAssigned (DocumentReference) to FullName. Links to JobDetails. |
| **JobDetails.aspx** | Read-only job detail: JobID, ServiceType, UserLocation, DateRequested, Status. Contractor details section: Name, Location (CompanyName), Phone, Rating. Resolves ContractorAssigned DocumentReference. **Note:** Has its own Firebase init (duplicate of Site1.Master). |
| **AssignContractor.aspx** | Job overview display. Lists available contractors (filtered by Status == "Available"). Assign button: updates Job (ContractorAssigned: DocumentReference, Status: "Assigned") and Contractor (Status: "Unavailable", isAvailable: false). |
| **ActiveJobList.aspx** | Full list of all active jobs (Status != "Completed"). Resolves contractor names via DocumentReference. |
| **RecentJobList.aspx** | Full list of all job invoices ordered by RequestedTime desc. Resolves User names (handles DocumentReference and string formats). Resolves Contractor names. |

### Services Module
| Page | Functionality |
|---|---|
| **Services.aspx** | Summary cards: Total, Active, Inactive counts. Services list table with search (name, description) and sort (name, price, status, ID). Edit links to ServiceEdit. Delete via modal (**hard delete** with `deleteDoc`). Add button links to ServiceAdd. |
| **ServiceAdd.aspx** | Create form: ServiceName, BasePrice, Description, Status dropdown. Auto-generates next ServiceID (S001, S002...) by scanning existing docs. Creates doc with slug-based ID via `setDoc`. |
| **ServiceEdit.aspx** | Edit form: ServiceName, BasePrice, Description, Status. Loads existing values via `getDoc`. Saves via `updateDoc`. |

### Finance Module
| Page | Functionality |
|---|---|
| **FinanceDesk.aspx** | **Pending Withdrawals:** Table of Withdrawals where Status == "pending", with search. Resolves contractor details (name, bank info) from Contractor collection. "Mark as Paid" button sets Status to "completed". **Monthly Statements:** Table of all active contractors (excludes IsDeleted), showing completed job count and total earnings from JobInvoice. "Send Monthly Statement" button sends email via EmailJS with templateParams: to_email, to_name, total_jobs, total_earnings, month_year. |

### Compliance Module
| Page | Functionality |
|---|---|
| **ComplianceDesk.aspx** | Lists contractors with VerificationStatus == "under_review". Shows FullName, Email, Phone, CreatedAt. "Review" link navigates to ContractorProfile for approval/rejection workflow. Search by Name or Email. |

### Reports Module
| Page | Functionality |
|---|---|
| **RevenueReports.aspx** | Summary cards: Total Revenue, Total Jobs Completed, Avg Revenue per Job, Top Service Type by Revenue. Revenue table (paginated, 10/page): JobID, ServiceType, ContractorName, UserLocation, TotalCost, PlatformFee (10%), ContractorEarnings (90%), PaymentMethod. CSV export. |
| **JobPerformance.aspx** | Summary cards: Total Jobs, Completed, Cancelled, Avg Completion Time. Job performance table (paginated): JobID, ServiceType, Status, RequestedTime, StartTime (DateAccepted), CompletionTime (DateCompleted), Duration, UserRating, CancellationReason. Cross-references Jobs and JobInvoice. CSV export. |
| **ContractorPerformance.aspx** | Summary cards: Total Contractors, Active Contractors, Avg Rating, Top Contractor. Performance table (paginated): ContractorName, ServiceTypes, TotalCompleted, AcceptanceRate, CancellationRate, AvgRating, TotalEarnings, LastActive. Aggregates from JobInvoice per contractor. CSV export. |
| **UserActivity.aspx** | Summary cards: Total Users, Active Users (last 30 days), New Users (this month), Most Used Service. User table (paginated): Name, Email, Phone, RegistrationDate, TotalJobsRequested, MostUsedService, Status. Cross-references Users and JobInvoice. CSV export. |

---

## 4. Data Integrity Notes

### Soft Delete (aligned with Flutter app)
- **Contractors:** Soft delete implemented. Sets `IsDeleted: true` and `AccountStatus: "Deactivated"`. Job history preserved.

### Hard Delete (NOT aligned with Flutter app)
- **Users:** Still using `deleteDoc` in both Users.aspx and UserProfile.aspx. **Needs migration to soft delete.**
- **Services:** Still using `deleteDoc` in Services.aspx. Consider soft delete or confirm this is intentional.

### Field Naming Collisions / Variants
- Contractor `Status` vs `AccountStatus`: AssignContractor writes `Status` ("Unavailable"); other pages use `AccountStatus`. Both fields coexist on the same document.
- Contractor `isAvailable` (camelCase): Written by AssignContractor. Verify Flutter app uses the same casing.
- User `Status` vs potential `AccountStatus`: Admin portal uses `Status`; verify Flutter app field name.
- Service `Status` vs `status` (lowercase): Services.aspx reads both `s.Status` and `s.status` as fallbacks.
- Service `BasePrice` vs `basePrice`: Services.aspx reads both as fallbacks.

### Duplicate Firebase Init
- **JobDetails.aspx** initializes its own Firebase app instance instead of using the one from Site1.Master. This creates a second app instance. Should use `window.db` from master page instead.

### EmailJS Configuration
- **Public Key:** Site1.Master line 27 -- `emailjs.init("YOUR_PUBLIC_KEY")`
- **Service ID:** FinanceDesk.aspx line ~428 -- `"service_vog61xa"`
- **Template ID:** FinanceDesk.aspx line ~429 -- `"template_r2d455i"`
- Template variables expected: `to_email`, `to_name`, `total_jobs`, `total_earnings`, `month_year`

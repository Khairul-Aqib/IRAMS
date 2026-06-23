# ASP.NET Admin Portal — Architecture Manifest

> Generated: 2026-04-29
> Purpose: Gap analysis against the IRAMS mobile (Flutter) contractor app
> Firebase Project: `iramsfyp`

---

## 1. Database Interactions (Firestore)

### Collection: `Users`

| Field              | Type              | Read | Write | Update | Delete | Pages                                     |
|--------------------|-------------------|------|-------|--------|--------|--------------------------------------------|
| FullName           | string            | Y    |       | Y      |        | Dashboard, Users, UserProfile, UserEdit, Jobs, RecentJobList, UserActivity |
| Email              | string            | Y    |       | Y      |        | Users, UserProfile, UserEdit, UserActivity |
| PhoneNumber        | string            | Y    |       | Y      |        | Users, UserProfile, UserEdit, UserActivity |
| UserID             | string            | Y    |       |        |        | Users (sort/filter)                        |
| Status             | string            | Y    |       | Y      |        | Users, UserProfile, UserEdit, UserActivity |
| RegistrationDate   | Timestamp         | Y    |       |        |        | Users, UserActivity                        |
| LastLogin          | Timestamp         | Y    |       |        |        | Users, UserProfile                         |
| EmergencyName      | string            | Y    |       | Y      |        | UserProfile, UserEdit                      |
| EmergencyPhone     | string            | Y    |       | Y      |        | UserProfile, UserEdit                      |
| ProfileImage       | string            | Y    |       | Y      |        | UserProfile, UserEdit                      |
| Name               | string            | Y    |       |        |        | Dashboard (fallback), UserActivity         |
| TotalJobs          | string/number     | Y    |       |        |        | Users (sort)                               |
| (whole doc)        |                   |      |       |        | Y      | Users (deleteDoc), UserProfile (deleteDoc) |

- **Operations**: `getDocs`, `getDoc`, `updateDoc`, `deleteDoc`, `getCountFromServer`

### Collection: `Contractor`

| Field                | Type              | Read | Write | Update | Delete | Pages                                          |
|----------------------|-------------------|------|-------|--------|--------|-------------------------------------------------|
| FullName             | string            | Y    |       | Y      |        | Contractors, ContractorProfile, ContractorEdit, Dashboard, Jobs, AssignContractor, ContractorPerformance, RevenueReports |
| Email                | string            | Y    |       | Y      |        | Contractors, ContractorProfile, ContractorEdit, ComplianceDesk |
| PhoneNumber          | string            | Y    |       | Y      |        | Contractors, ContractorProfile, ContractorEdit, JobDetails, ComplianceDesk |
| ContractorID         | string            | Y    |       |        |        | Contractors, Dashboard (fallback)              |
| AccountStatus        | string            | Y    |       | Y      |        | Contractors, ContractorProfile, ContractorEdit |
| VerificationStatus   | string            | Y    |       | Y      |        | Contractors, ContractorProfile, ContractorEdit, ComplianceDesk (query: `"under_review"`) |
| ServiceTypes         | array\|string     | Y    |       | Y      |        | Contractors, ContractorProfile, ContractorEdit, AssignContractor |
| CompanyName          | string            | Y    |       | Y      |        | ContractorProfile, ContractorEdit, Dashboard, JobDetails |
| CompanyContactPhone  | string            | Y    |       | Y      |        | ContractorProfile, ContractorEdit              |
| TotalJobs            | number            | Y    |       |        |        | Contractors                                    |
| LastLogin            | Timestamp         | Y    |       |        |        | Contractors, ContractorProfile                 |
| ProfileImage         | string            | Y    |       | Y      |        | ContractorProfile, ContractorEdit              |
| IcFrontUrl           | string (URL)      | Y    |       |        |        | ContractorProfile                              |
| IcBackUrl            | string (URL)      | Y    |       |        |        | ContractorProfile                              |
| DrivingLicenceUrl    | string (URL)      | Y    |       |        |        | ContractorProfile                              |
| GdlLicenseUrl        | string (URL)      | Y    |       |        |        | ContractorProfile                              |
| VehicleGrantUrl      | string (URL)      | Y    |       |        |        | ContractorProfile                              |
| PuspakomUrl          | string (URL)      | Y    |       |        |        | ContractorProfile                              |
| Rating               | number            | Y    |       |        |        | JobDetails, AssignContractor                   |
| CreatedAt            | Timestamp         | Y    |       |        |        | ComplianceDesk                                 |
| Status               | string            | Y    |       | Y      |        | AssignContractor (filter: `"Available"`), AssignContractor (set to `"Busy"`) |
| Location             | string            | Y    |       |        |        | AssignContractor                               |
| Distance             | string/number     | Y    |       |        |        | AssignContractor                               |
| BankName             | string            | Y    |       |        |        | FinanceDesk                                    |
| BankAccount          | string            | Y    |       |        |        | FinanceDesk                                    |
| (whole doc)          |                   |      |       |        | Y      | Contractors (deleteDoc), ContractorProfile (deleteDoc) |

- **Operations**: `getDocs`, `getDoc`, `updateDoc`, `deleteDoc`, `getCountFromServer`
- **Queries**: `where("VerificationStatus", "==", "under_review")`

### Collection: `Jobs`

| Field              | Type                | Read | Write | Update | Delete | Pages                                      |
|--------------------|---------------------|------|-------|--------|--------|--------------------------------------------|
| JobID              | string              | Y    |       |        |        | Dashboard, Jobs, JobDetails, AssignContractor |
| ServiceType        | string              | Y    |       |        |        | Dashboard, Jobs, JobDetails, UserProfile, ActiveJobList, AssignContractor |
| UserLocation       | string              | Y    |       |        |        | Dashboard, Jobs, JobDetails, UserProfile, ActiveJobList, AssignContractor |
| Status             | string              | Y    |       | Y      |        | Dashboard (filter: `!= "Completed"`), Jobs, JobDetails, UserProfile, ActiveJobList, AssignContractor (set to `"Assigned"`) |
| ContractorAssigned | DocumentReference   | Y    |       | Y      |        | Dashboard, Jobs, JobDetails, ActiveJobList, AssignContractor |
| UserID             | DocumentRef/string  | Y    |       |        |        | UserProfile, Jobs                          |
| DateRequested      | Timestamp           | Y    |       |        |        | Jobs, JobDetails, UserProfile, AssignContractor |
| TotalCost          | number              | Y    |       |        |        | Jobs, UserProfile                          |
| PaymentMethod      | string              | Y    |       |        |        | UserProfile                                |
| DateAccepted       | Timestamp           | Y    |       |        |        | JobPerformance                             |
| DateCompleted      | Timestamp           | Y    |       |        |        | JobPerformance                             |
| (whole collection) |                     |      |       |        |        | (no deletes from admin)                    |

- **Operations**: `getDocs`, `getDoc`, `updateDoc`, `getCountFromServer`
- **Queries**: `where("Status", "!=", "Completed")`, `limit(10)`

### Collection: `JobInvoice`

| Field              | Type              | Read | Write | Update | Delete | Pages                                      |
|--------------------|-------------------|------|-------|--------|--------|--------------------------------------------|
| JobID              | string            | Y    |       |        |        | Dashboard, RecentJobList, JobPerformance, RevenueReports |
| UserID             | DocRef/string     | Y    |       |        |        | Dashboard, RecentJobList, UserActivity     |
| ContractorID       | string            | Y    |       |        |        | Dashboard, ContractorProfile, RecentJobList, ContractorPerformance, RevenueReports |
| ServiceType        | string            | Y    |       |        |        | Dashboard, ContractorProfile, RecentJobList, ContractorPerformance, JobPerformance, RevenueReports |
| UserLocation       | string            | Y    |       |        |        | Dashboard, ContractorProfile, RecentJobList, RevenueReports |
| TotalCost          | number            | Y    |       |        |        | Dashboard, ContractorProfile, RecentJobList, ContractorPerformance, RevenueReports |
| PaymentMethod      | string            | Y    |       |        |        | Dashboard, ContractorProfile, RecentJobList, RevenueReports |
| RequestedTime      | Timestamp         | Y    |       |        |        | Dashboard, ContractorProfile, RecentJobList, ContractorPerformance, JobPerformance, UserActivity |
| Status             | string            | Y    |       |        |        | ContractorProfile, ContractorPerformance, JobPerformance |
| UserRating         | number            | Y    |       |        |        | ContractorPerformance, JobPerformance      |
| CompletionTime     | Timestamp         | Y    |       |        |        | ContractorPerformance                      |
| StartTime          | Timestamp         | Y    |       |        |        | ContractorPerformance                      |
| CancellationReason | string            | Y    |       |        |        | JobPerformance                             |

- **Operations**: `getDocs` only (read-only from admin)
- **Queries**: `orderBy("RequestedTime", "desc")`, `where("ContractorID", "==", id)`, `limit(5)`

### Collection: `Services`

| Field        | Type      | Read | Write | Update | Delete | Pages                          |
|--------------|-----------|------|-------|--------|--------|--------------------------------|
| ServiceID    | string    | Y    | Y     |        |        | Services, ServiceAdd           |
| ServiceName  | string    | Y    | Y     | Y      |        | Services, ServiceAdd, ServiceEdit, ContractorEdit |
| BasePrice    | string    | Y    | Y     | Y      |        | Services, ServiceAdd, ServiceEdit |
| Description  | string    | Y    | Y     | Y      |        | Services, ServiceAdd, ServiceEdit |
| Status       | string    | Y    | Y     | Y      |        | Services, ServiceAdd, ServiceEdit |
| CreatedAt    | Date      |      | Y     |        |        | ServiceAdd                     |
| (whole doc)  |           |      |       |        | Y      | Services (deleteDoc)           |

- **Operations**: `getDocs`, `getDoc`, `setDoc`, `updateDoc`, `deleteDoc`, `getCountFromServer`
- **Doc ID strategy**: slugified service name (e.g., `towing`)

### Collection: `Withdrawals`

| Field              | Type      | Read | Write | Update | Delete | Pages       |
|--------------------|-----------|------|-------|--------|--------|-------------|
| ContractorID       | string    | Y    |       |        |        | FinanceDesk |
| ContractorName     | string    | Y    |       |        |        | FinanceDesk |
| ContractorDisplayID| string    | Y    |       |        |        | FinanceDesk |
| Amount             | number    | Y    |       |        |        | FinanceDesk |
| BankName           | string    | Y    |       |        |        | FinanceDesk |
| BankAccount        | string    | Y    |       |        |        | FinanceDesk |
| RequestedAt        | Timestamp | Y    |       |        |        | FinanceDesk |
| Status             | string    | Y    |       | Y      |        | FinanceDesk (query: `"pending"`, update to `"completed"`) |

- **Operations**: `getDocs`, `updateDoc`
- **Queries**: `where("Status", "==", "pending")`

---

## 2. Existing Pages & Core Functionality

### Authentication

| Page           | Functionality                                                              |
|----------------|----------------------------------------------------------------------------|
| **Login.aspx** | Hard-coded admin credentials (`admin@irams.com` / `admin123`). Sets `Session["IsAdmin"]` and `Session["AdminName"]`. |
| **Site1.Master** | Auth guard: redirects to Login if `Session["IsAdmin"]` is null. Displays admin name + logout button. Initializes Firebase (anonymous auth) and Firestore globally. Loads sidebar badge counts for Compliance & Finance desks. |

### Dashboard

| Page             | Functionality                                                            |
|------------------|--------------------------------------------------------------------------|
| **Dashboard.aspx** | Summary cards: total Users, Contractors, Jobs, Services (via `getCountFromServer`). Active Jobs table (Status != Completed, limit 10) with contractor name lookup. Recent Job Invoices table (ordered by RequestedTime desc, limit 5) with user and contractor name lookups. |

### Users Management

| Page              | Functionality                                                           |
|-------------------|-------------------------------------------------------------------------|
| **Users.aspx**    | Lists all users from `Users` collection. Search by Name/Email/UserID. Sort by name, ID, status, registration date, last login. Delete user (with modal confirmation). |
| **UserProfile.aspx** | Displays single user profile (FullName, Email, Phone, Status, EmergencyName, EmergencyPhone, ProfileImage, LastLogin). Lists jobs linked to the user (client-side match on `Jobs.UserID`). Suspend/Activate toggle (updates `Status` field). Delete user with modal. Edit link to UserEdit. |
| **UserEdit.aspx** | Edit form for FullName, Email, PhoneNumber, EmergencyName, EmergencyPhone, Status. Profile image upload via C# WebMethod (base64 -> server `/images/` folder). Updates `Users` doc via `updateDoc`. |

### Contractors Management

| Page                   | Functionality                                                      |
|------------------------|--------------------------------------------------------------------|
| **Contractors.aspx**   | Lists all contractors from `Contractor` collection. Search by Name/Email/ContractorID. Sort by name, ID, account status, verification status, total jobs, last login. Delete contractor with modal. |
| **ContractorProfile.aspx** | Displays contractor profile (FullName, Email, Phone, ServiceTypes, AccountStatus, CompanyName, CompanyContactPhone, VerificationStatus, ProfileImage). Verification Documents grid (IcFrontUrl, IcBackUrl, DrivingLicenceUrl, GdlLicenseUrl, VehicleGrantUrl, PuspakomUrl) with lightbox viewer. Approval workflow: Approve/Reject buttons visible when VerificationStatus is `"under_review"` or `"pending"` (updates to `"approved"` / `"rejected"`). Job Invoice table (query `JobInvoice` by ContractorID). Suspend/Activate toggle (updates AccountStatus). Delete contractor with modal. |
| **ContractorEdit.aspx** | Edit form for FullName, Email, PhoneNumber, CompanyName, CompanyContactPhone, AccountStatus, VerificationStatus. Multi-select ServiceTypes loaded dynamically from `Services` collection. Profile image upload (local save). Updates `Contractor` doc via `updateDoc`. |

### Jobs Management

| Page                    | Functionality                                                     |
|-------------------------|-------------------------------------------------------------------|
| **Jobs.aspx**           | Lists all jobs from `Jobs` collection with user/contractor name resolution. Search by JobID, ServiceType, user name, contractor name, location, status. Sort by request date (newest/oldest) and status. Links to JobDetails. |
| **JobDetails.aspx**     | Displays single job details: JobID, ServiceType, UserLocation, DateRequested, Status. Contractor section: resolves `ContractorAssigned` DocumentReference to show FullName, CompanyName, PhoneNumber, Rating. Has its own Firebase init (duplicated from Master). |
| **AssignContractor.aspx** | Shows job overview. Lists available contractors (filtered by `Status == "Available"`). Assign button: updates `Jobs.ContractorAssigned` to a DocumentReference and sets `Status: "Assigned"`, updates contractor `Status: "Busy"`. |
| **ActiveJobList.aspx**  | Full list of all non-completed jobs (`Status != "Completed"`). Shows JobID, ServiceType, UserLocation, Status, Contractor name. |
| **RecentJobList.aspx**  | Full list of all `JobInvoice` documents ordered by RequestedTime desc. Resolves UserID and ContractorID to display names. Shows JobID, User, UserLocation, ServiceType, TotalCost, PaymentMethod, Contractor. |

### Services Management

| Page               | Functionality                                                          |
|--------------------|------------------------------------------------------------------------|
| **Services.aspx**  | Summary cards: Total, Active, Inactive service counts. Lists all services. Search by name/description. Sort by name, price, status, ServiceID. Edit and Delete actions. |
| **ServiceAdd.aspx** | Add new service form: ServiceName, BasePrice, Description, Status. Auto-generates next `ServiceID` (S001, S002...). Creates doc with slugified name as doc ID via `setDoc`. |
| **ServiceEdit.aspx** | Edit service form: ServiceName, BasePrice, Description, Status. Loads by doc ID from query string. Updates via `updateDoc`. |

### Reports (tabbed navigation)

| Page                         | Functionality                                                  |
|------------------------------|----------------------------------------------------------------|
| **RevenueReports.aspx**      | Summary: Total Revenue, Total Jobs Completed, Avg Revenue/Job, Top Service by Revenue. Table: JobID, ServiceType, ContractorName, UserLocation, TotalCost, PlatformFee (10% of TotalCost), ContractorEarnings (90%), PaymentMethod. Paginated. Export CSV link (not wired). |
| **JobPerformance.aspx**      | Summary: Total Jobs, Completed, Cancelled, Avg Completion Time. Table: per-invoice row with JobID, ServiceType, Status, RequestedTime, StartTime (DateAccepted), CompletionTime (DateCompleted), Duration, UserRating, CancellationReason. Cross-references `Jobs` and `JobInvoice`. Paginated. Export CSV link (not wired). |
| **ContractorPerformance.aspx** | Summary: Total Contractors, Active Contractors, Avg Rating, Top Contractor. Table: per-contractor aggregation from `JobInvoice` — Name, ServiceTypes, TotalCompleted, AcceptanceRate, CancellationRate, AvgRating, TotalEarnings, LastActive. Paginated. CSV export (functional). |
| **UserActivity.aspx**        | Summary: Total Users, Active Users (30 days), New Users (this month), Most Used Service. Table: per-user — Name, Email, Phone, RegistrationDate, TotalJobs, MostUsedService, Status. Cross-references `Users` and `JobInvoice`. Paginated. CSV export (functional). |

### Operations Desks

| Page                   | Functionality                                                      |
|------------------------|--------------------------------------------------------------------|
| **ComplianceDesk.aspx** | Lists contractors with `VerificationStatus == "under_review"`. Search by Name/Email. Each row links to ContractorProfile for document review and approve/reject workflow. Updates sidebar badge count. |
| **FinanceDesk.aspx**   | Lists `Withdrawals` where `Status == "pending"`. Resolves ContractorID to get name, bank info. Search by Name/ContractorID. "Mark as Paid" button updates `Withdrawals.Status` to `"completed"`. Updates sidebar badge count. |

---

## 3. Pending Features & Incomplete Placeholders

### Empty Code-Behind Files (no server-side logic)
All pages except `Login.aspx.cs`, `Site1.Master.cs`, `UserEdit.aspx.cs`, and `ContractorEdit.aspx.cs` have completely empty `Page_Load` methods. All Firestore interactions are client-side JavaScript. This means:
- No server-side validation on any data operation
- No server-side authorization beyond the session check in `Site1.Master.cs`

### Dashboard.aspx
- **No click-through links** on summary cards (Users, Contractors, Jobs, Services counts are display-only)
- **No "View All"** links for Active Jobs or Recent Invoices tables

### Jobs Management
- **AssignContractor.aspx**: Lists contractors by `Status == "Available"` but the `Contractor` collection commonly uses `AccountStatus`, not `Status` — likely broken or requires the mobile app to set a separate `Status` field for real-time availability
- **AssignContractor.aspx**: `Distance` field displayed but never calculated — always shows "N/A"
- **JobDetails.aspx**: Duplicates Firebase initialization (has its own `initializeApp` call instead of using the global `db` from Site1.Master)
- **JobDetails.aspx**: No "Assign Contractor" button or link to `AssignContractor.aspx` from this page
- **No job status update** capability from admin (cannot cancel, complete, or reassign jobs)
- **No job creation** from admin side

### Reports
- **RevenueReports.aspx**: "Export (CSV)" link exists but has no click handler wired
- **JobPerformance.aspx**: "Export (CSV)" link exists but has no click handler wired
- **RevenueReports.aspx**: Search input exists but has no event listener attached
- **All report pages**: Filter icon (lucide `filter`) is rendered but has no functionality
- **No date-range filtering** on any report

### ContractorPerformance.aspx
- Export CSV button ID is `exportContractorCSV` but the HTML has `id="exportCSV"` — **export may be broken** (element lookup mismatch)
- Search input rendered but no search event listener attached

### UserActivity.aspx
- Search input rendered but no search event listener attached

### Services Management
- **No service detail/view page** — only list, add, and edit

### User Management
- **No user creation** from admin side (users are created from mobile app only)
- **UserEdit.aspx**: Profile image upload uses C# WebMethod but `ContractorEdit.aspx` does not — contractor image upload shows an alert asking to "manually save the image" (incomplete implementation)

### Finance Desk
- **No withdrawal history view** (only pending withdrawals are shown)
- **No confirmation modal** for "Mark as Paid" — only a `confirm()` dialog

### Compliance Desk
- **No rejection reason input** — approve/reject uses simple `confirm()` dialogs with no notes field

### Authentication
- **Hard-coded credentials** — no Firestore-backed admin accounts
- **No password reset, multi-admin support, or role-based access**
- **Anonymous Firebase auth** used for Firestore access — no admin-specific Firebase authentication

### General
- **No notification system** (no push notifications or email alerts)
- **No audit trail / activity logging** for admin actions
- **No real-time listeners** — all data is fetched on page load only (no `onSnapshot`)
- **No mobile-responsive sidebar** (fixed 256px sidebar with no collapse/hamburger)

---

## Appendix: Sidebar Navigation Order

1. Dashboard
2. Users
3. Contractors
4. Jobs
5. Reports (lands on Revenue Report; tabs: Revenue, Job Performance, Contractor Performance, User Activity)
6. Service Management
7. Compliance Desk (badge: count of `VerificationStatus == "under_review"`)
8. Finance Desk (badge: count of `Withdrawals.Status == "pending"`)

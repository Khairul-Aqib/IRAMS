# Firebase Integration Blueprint

> Generated: 2026-04-26
> Scope: All 22 `.aspx` pages in `AdminPage/`
> SDK: Firebase JavaScript SDK v11.6.1 (client-side, loaded via `<script type="module">`)
> Auth: Anonymous sign-in via `Site1.Master`; Firestore exposed as `window.db`

---

## Overall Assessment

**21 of 22 pages are wired to Firestore.** The single exception is `Login.aspx`, which uses server-side ASP.NET authentication and has no need for Firestore. All dynamic tables, summary cards, and stat counters pull live data — there are no fake sample rows or dummy revenue numbers anywhere in the project.

The items flagged below are minor configuration-level hardcoding (UI option lists, fallback images, document field key mappings) rather than missing database connections.

---

## Firestore Collections Referenced Across the Project

| Collection | Pages That Read It |
|---|---|
| `Contractor` | Dashboard, Contractors, ContractorProfile, ContractorEdit, ContractorPerformance, AssignContractor, ActiveJobList, RevenueReports, RecentJobList, ComplianceDesk, FinanceDesk |
| `Users` | Dashboard, Users, UserProfile, UserEdit, UserActivity, RecentJobList |
| `Jobs` | Dashboard, Jobs, JobDetails, ActiveJobList, AssignContractor, UserProfile, JobPerformance |
| `JobInvoice` | Dashboard, RevenueReports, RecentJobList, ContractorProfile, ContractorPerformance, UserActivity, JobPerformance |
| `Services` | Dashboard, Services, ServiceAdd, ServiceEdit |
| `Withdrawals` | FinanceDesk |

---

## Page-by-Page Breakdown

### Fully Integrated — No Action Needed

These pages query Firestore for all displayed data. Tables, cards, and counters are 100% dynamic.

| Page | Collections | Notes |
|---|---|---|
| `Dashboard.aspx` | Users, Contractor, Jobs, Services, JobInvoice | 4 count cards via `getCountFromServer()`; active jobs list (top 10); recent invoices (top 5) |
| `Users.aspx` | Users | Full CRUD table with search, sort, delete |
| `UserProfile.aspx` | Users, Jobs | Profile fields + user jobs table; suspend/activate/delete; fallback avatar `images/default-avatar.png` |
| `UserEdit.aspx` | Users | Edit form populated from Firestore; profile image upload |
| `UserActivity.aspx` | Users, JobInvoice | 4 summary cards (Total/Active/New users, Top Service); activity table with pagination; CSV export |
| `Contractors.aspx` | Contractor | Full CRUD table with search, sort, delete |
| `ContractorPerformance.aspx` | Contractor, JobInvoice | 4 summary cards; performance table with pagination; CSV export |
| `Jobs.aspx` | Jobs | Full table with user/contractor name lookups; search and sort |
| `JobDetails.aspx` | Jobs, Contractor | Job overview + contractor details resolved via DocumentReference |
| `ActiveJobList.aspx` | Jobs, Contractor | Jobs where Status != "Completed"; contractor name lookups |
| `RecentJobList.aspx` | JobInvoice, Users, Contractor | Ordered by RequestedTime desc; user + contractor name resolution |
| `JobPerformance.aspx` | JobInvoice, Jobs | 4 summary cards; duration calculations; pagination |
| `RevenueReports.aspx` | JobInvoice, Contractor | Total Revenue / Total Jobs / Avg Revenue / Top Service cards; revenue table with pagination; platform fee calculation (10%) |
| `Services.aspx` | Services | 3 count cards (Total/Active/Inactive); full table with search, sort, delete |
| `ServiceAdd.aspx` | Services | Auto-generates ServiceID (S001, S002...); writes new doc |
| `ServiceEdit.aspx` | Services | Edit form loaded by ID; writes updates |
| `AssignContractor.aspx` | Contractor, Jobs | Loads job details + available contractors; assigns via `updateDoc` |
| `ComplianceDesk.aspx` | Contractor | Queries `VerificationStatus == "under_review"`; links to ContractorProfile for review |
| `FinanceDesk.aspx` | Withdrawals, Contractor | Queries `Status == "pending"`; resolves contractor bank details; Mark as Paid workflow |

---

### Pages With Minor Hardcoded Elements

These pages ARE connected to Firestore but contain small amounts of static configuration that is acceptable or intentional.

#### `ContractorProfile.aspx`

- **Current State:**
  - Profile data, verification documents, and job invoices are all loaded from Firestore
  - The 6 document type keys are hardcoded in a JS array:
    ```
    IcFrontUrl, IcBackUrl, DrivingLicenceUrl,
    GdlLicenseUrl, VehicleGrantUrl, PuspakomUrl
    ```
  - Initial profile image src is `https://via.placeholder.com/150` (replaced on load)
  - Fallback avatar: `images/default-avatar.png`
- **Data Mapping:** `Contractor`, `JobInvoice`
- **Action Required:** None — document field keys are a stable contract with the mobile app. The placeholder image is replaced immediately on load.

#### `ContractorEdit.aspx`

- **Current State:**
  - All form fields load from and save to Firestore
  - The service type checkboxes are hardcoded in HTML:
    ```
    Towing, Battery Replacement, Fuel Delivery,
    Change Tyre, Vehicle Unlock, Minor Repair
    ```
  - These are checked/unchecked dynamically based on the contractor's `ServiceTypes` array in Firestore
  - Placeholder image: `https://via.placeholder.com/150`
- **Data Mapping:** `Contractor`; also uses Firebase Storage for profile image upload
- **Potential Improvement:** Could dynamically generate checkboxes from the `Services` collection instead of hardcoding, so new service types added via ServiceAdd.aspx would automatically appear.

---

### No Firestore Connection (By Design)

#### `Login.aspx`

- **Current State:** Server-side ASP.NET authentication page. Contains only static UI elements (logo, background image, "IRAMS" title text, login form). Authentication is handled in `Login.aspx.cs` codebehind.
- **Data Mapping:** None needed — this is the auth gate before the admin panel loads.
- **Action Required:** None.

---

## Architecture Notes

### Master Page (`Site1.Master`)

The master page handles all Firebase initialization for every child page:

1. Loads Firebase App, Firestore, and Auth SDKs (v11.6.1)
2. Initializes the app and exposes `window.db` globally
3. Signs in anonymously and dispatches `firebase-auth-ready` event
4. Runs sidebar badge count queries (Compliance + Finance) on every page load

Every child page listens for `firebase-auth-ready` before executing any Firestore queries, ensuring `window.db` is available.

### Data Flow Pattern (All Pages)

```
Site1.Master loads → Firebase init → signInAnonymously()
  → onAuthStateChanged fires → dispatches "firebase-auth-ready"
    → Child page listener runs → Firestore queries execute
      → DOM updated with results
```

### Firestore Collections Schema (As Used)

| Collection | Key Fields | Written By |
|---|---|---|
| `Contractor` | FullName, Email, PhoneNumber, ContractorID, ServiceTypes[], AccountStatus, VerificationStatus, CompanyName, CompanyContactPhone, ProfileImage, TotalJobs, LastLogin, IcFrontUrl, IcBackUrl, DrivingLicenceUrl, GdlLicenseUrl, VehicleGrantUrl, PuspakomUrl, BankName, BankAccount, CreatedAt | Mobile App |
| `Users` | FullName, Email, PhoneNumber, UserID, AccountStatus, ProfileImage, RegistrationDate, LastLogin | Mobile App |
| `Jobs` | JobID, ServiceType, UserID, UserLocation, ContractorRef (DocumentReference), Status, DateRequested, DateCompleted | Mobile App |
| `JobInvoice` | JobID, ContractorID, ServiceType, UserID, UserLocation, TotalCost, PaymentMethod, Status, RequestedTime | System |
| `Services` | ServiceID, ServiceName, BasePrice, Description, Status | Admin Panel |
| `Withdrawals` | ContractorID, ContractorName, ContractorDisplayID, Amount, Status, RequestedAt, BankName, BankAccount | Mobile App |

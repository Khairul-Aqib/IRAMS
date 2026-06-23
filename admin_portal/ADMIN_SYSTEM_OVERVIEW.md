# IRAMS Admin Portal — System Overview

> Generated: 2026-05-05
> Audience: Full-stack engineers integrating the Flutter user app with this admin portal
> Source of truth: scan of `AdminPage/` (22 `.aspx` pages, code-behind, master page)

---

## 1. Tech Stack & Architecture

| Layer | Technology |
|---|---|
| Framework | **ASP.NET Web Forms** (.NET Framework 4.x) — server controls, master page, code-behind in C# |
| Runtime hosting | IIS / IIS Express (Visual Studio project, `AdminPage.sln`) |
| UI rendering | Server-rendered `.aspx` pages with Tailwind CSS (CDN) and Lucide icons (CDN) |
| Database client | **Firebase JavaScript SDK v11.6.1** (loaded via ES modules from `gstatic.com`) |
| Database access pattern | **Client-side only** — every `.aspx` page contains a `<script type="module">` block that talks directly to Firestore. C# code-behind files are essentially empty. |
| Auth (Firestore) | **Anonymous** (`signInAnonymously`) — initialized once in `Site1.Master`, exposes `window.db` globally |
| Auth (Admin login) | **Server-side ASP.NET Session** — hardcoded credentials in `Login.aspx.cs` (`admin@irams.com` / `admin123`). Completely decoupled from Firebase. |
| Email | **EmailJS** v4 browser SDK (CDN) for monthly contractor statements |
| File storage | **Firebase Storage** imported in `ContractorEdit.aspx` (fallback to local `~/images/` via WebMethod) |

### Project Structure

```
AdminPage/                    (solution root)
├── AdminPage/                (web project)
│   ├── *.aspx                (22 pages — flat, no folders)
│   ├── *.aspx.cs             (code-behind — mostly empty Page_Load)
│   ├── *.aspx.designer.cs    (auto-generated control declarations)
│   ├── Site1.Master          (shared layout + Firebase init)
│   ├── Web.config            (auth, session, IIS config)
│   ├── Key/                  (service account JSON — present but unused)
│   ├── images/               (uploaded user/contractor profile images)
│   ├── css.css               (custom styles — minimal, mostly Tailwind)
│   ├── packages.config       (NuGet refs incl. Google.Cloud.Firestore — also unused)
│   └── protos/               (gRPC proto files from NuGet — unused)
├── packages/                 (NuGet packages)
└── AdminPage.sln
```

**Key observation:** The C# Firestore SDK is referenced in `.csproj` but **none of the code-behind files use it**. All database I/O is JavaScript. Server-side .NET handles only admin login, session, and the image-upload `WebMethod`.

### Initialization Flow

```
Browser loads .aspx
  → Site1.Master runs
    → Firebase app initializes with project "iramsfyp"
    → window.db = getFirestore(app)
    → signInAnonymously(auth) [requires Anonymous provider enabled in Console]
    → onAuthStateChanged fires → dispatches custom event "firebase-auth-ready"
      → Per-page <script type="module"> waits for that event before any read
```

---

## 2. Firestore Integration

Firebase project: **`iramsfyp`** (config hardcoded in `Site1.Master:113-122`).

### Collections Used

| Collection | Doc ID Convention | Friendly ID Field | Read Pages | Write Pages |
|---|---|---|---|---|
| **`Users`** | Firebase Auth UID (assumed — written by mobile app) | `UserID` (e.g. `U001`) | Dashboard, Users, UserProfile, UserEdit, UserActivity, Jobs, RecentJobList | UserEdit, UserProfile (status), Users/UserProfile (delete) |
| **`Contractor`** | Firebase Auth UID (assumed) | `ContractorID` (e.g. `C001`) | Dashboard, Contractors, ContractorProfile, ContractorEdit, ComplianceDesk, RevenueReports, ContractorPerformance, FinanceDesk, AssignContractor, JobDetails | Contractors (soft delete), ContractorProfile (verify/suspend/delete), ContractorEdit, AssignContractor (Status, isAvailable) |
| **`Jobs`** | Firestore auto-ID | `JobID` (string) | Dashboard, Jobs, JobDetails, ActiveJobList, AssignContractor, UserProfile, JobPerformance | AssignContractor (`ContractorAssigned`, `Status`) |
| **`JobInvoice`** | Firestore auto-ID | `JobID` | Dashboard, RevenueReports, RecentJobList, ContractorProfile, ContractorPerformance, FinanceDesk, JobPerformance, UserActivity | **(read-only — written by mobile app)** |
| **`Services`** | **Slug-based** (e.g. `towing`, `battery-replacement`) | `ServiceID` (e.g. `S001`) | Dashboard, Services, ServiceAdd (next-ID calc), ServiceEdit, ContractorEdit | ServiceAdd, ServiceEdit, Services (hard delete) |
| **`Withdrawals`** | Firestore auto-ID | `ContractorDisplayID` | FinanceDesk, Site1.Master (badge) | FinanceDesk (Status → "completed") |

### ID Strategy — **Mixed and Inconsistent**

The admin portal stores **two distinct IDs per entity**:

1. **Document ID** — used as the navigation key (`?id=...` URL param, `getDoc(doc(db, "Contractor", id))`). For Users and Contractors, this is presumed to be the Firebase Auth UID assigned by the mobile app at signup. The admin portal never generates new User/Contractor doc IDs.
2. **Friendly ID field** — `UserID` / `ContractorID` / `ServiceID`, in `U001` / `C001` / `S001` format. Displayed in tables, used for search, but **never used as a Firestore key for navigation** (except in `JobInvoice` queries, see below).

**Where it gets messy — `JobInvoice` referencing pattern (`Dashboard.aspx:127-141`):**

```js
// JobInvoice.UserID can be three different formats:
if (typeof d.UserID === "object" && d.UserID.path) {  // (1) DocumentReference
    userSnap = await getDoc(d.UserID);
}
else if (typeof d.UserID === "string") {              // (2) Path string OR (3) raw ID
    let uid = d.UserID;
    if (uid.includes('/')) uid = uid.split('/').pop(); // strips "/Users/U004" → "U004"
    userSnap = await getDoc(doc(db, "Users", uid));
}
```

`JobInvoice.ContractorID` is used directly as the Contractor doc ID at `Dashboard.aspx:156`:
```js
const cSnap = await getDoc(doc(db, "Contractor", d.ContractorID));
```

This means **`JobInvoice.ContractorID` is expected to equal the Contractor doc ID**, *not* the friendly `C001`. The field name is misleading.

### Field Casing Inconsistencies

| Field | Variants seen | Pages |
|---|---|---|
| `Status` vs `AccountStatus` (Contractor) | Both fields coexist on same doc | `AssignContractor` writes `Status: "Unavailable"`; everywhere else uses `AccountStatus: "Active" / "Deactivated"` |
| `isAvailable` (camelCase) | Used by AssignContractor only | confirm Flutter app casing |
| `Status` vs `status` (Service) | Both read as fallback | `Services.aspx` reads `s.Status \|\| s.status` |
| `BasePrice` vs `basePrice` | Both read as fallback | `Services.aspx` |
| `ContractorID` vs `contractorId` (Withdrawals) | Both read as fallback | `FinanceDesk.aspx:201,346` |

---

## 3. Route / Page Map

All paths are root-relative (`.aspx` files live directly under `AdminPage/`).

### Authentication
| Page | Route | Function |
|---|---|---|
| Login | `/Login.aspx` | Admin login (server-side postback). Sets `Session["IsAdmin"]`. **No Firestore.** Hardcoded creds. |

### Layout
| Component | Function |
|---|---|
| `Site1.Master` | Sidebar nav, top bar with admin name + logout, Firebase init, EmailJS init, sidebar badges (Compliance + Finance) |

### Dashboard
| Page | Function |
|---|---|
| `Dashboard.aspx` | 4 count cards (Users / Contractors / Jobs / Services via `getCountFromServer`); Active Jobs table (top 10, Status != Completed); Recent Invoices table (top 5, ordered by RequestedTime desc) |

### Users Module
| Page | Function |
|---|---|
| `Users.aspx` | List + search + sort; **hard delete** via modal; links to UserProfile |
| `UserProfile.aspx` | Profile display; Suspend/Activate; **hard delete**; user's job history |
| `UserEdit.aspx` | Edit form + profile image upload (base64 → server `WebMethod` → `images/` folder) |
| `UserActivity.aspx` | 4 cards + paginated activity table; CSV export |

### Contractors Module
| Page | Function |
|---|---|
| `Contractors.aspx` | List + search + sort; **soft delete** (`IsDeleted: true`); links to ContractorProfile |
| `ContractorProfile.aspx` | Profile + verification documents grid (`ComplianceDocumentsMetadata` map); Approve/Reject workflow; Suspend/Activate; soft delete; invoice history |
| `ContractorEdit.aspx` | Edit form; ServiceTypes checkboxes loaded from `Services` collection; profile image upload |
| `ContractorPerformance.aspx` | 4 cards + paginated table aggregated from JobInvoice; CSV export |

### Jobs Module
| Page | Function |
|---|---|
| `Jobs.aspx` | All jobs; resolves UserID and ContractorAssigned references |
| `JobDetails.aspx` | Read-only detail view. **⚠ Has its own duplicate Firebase init** instead of using `window.db` |
| `AssignContractor.aspx` | Job overview + filter Contractors where `Status == "Available"`; assign workflow |
| `ActiveJobList.aspx` | All Status != Completed |
| `RecentJobList.aspx` | All JobInvoice ordered by RequestedTime desc |
| `JobPerformance.aspx` | 4 cards + paginated performance table; cross-references Jobs and JobInvoice |

### Services Module
| Page | Function |
|---|---|
| `Services.aspx` | List + search + sort; **hard delete**; links to Add/Edit |
| `ServiceAdd.aspx` | Auto-generates next `ServiceID` (S001, S002...); writes via `setDoc` with slug-based doc ID |
| `ServiceEdit.aspx` | Edit form |

### Operations Modules
| Page | Function |
|---|---|
| `ComplianceDesk.aspx` | Lists contractors where `VerificationStatus == "under_review"`; "Review" → ContractorProfile |
| `FinanceDesk.aspx` | Pending Withdrawals table + "Mark as Paid"; Monthly Statements table + "Send Monthly Statement" via EmailJS |
| `RevenueReports.aspx` | 4 cards + paginated revenue table (Platform Fee 10%, Contractor 90%); CSV export |

**Total: 22 pages** (1 Login + 1 Master + 1 Dashboard + 4 Users + 4 Contractors + 6 Jobs + 3 Services + 3 Operations).

---

## 4. Critical Logic

### A. Assigning a Contractor to a Job

Source: `AssignContractor.aspx:90-110`

```
URL param:  ?jobID={Jobs doc ID}
Trigger:    Admin clicks "Assign" button next to an available contractor

Step 1 — Read available contractors:
    onSnapshot(collection(db, "Contractor"))
    → filter client-side by  data.Status === "Available"

Step 2 — On Assign click:
    confirm("...");

Step 3 — Update Job document:
    updateDoc(doc(db, "Jobs", jobId), {
        ContractorAssigned: doc(db, "Contractor", contractorId),  // DocumentReference
        Status: "Accepted"
    });

Step 4 — Update Contractor document:
    updateDoc(doc(db, "Contractor", contractorId), {
        Status: "Unavailable",
        isAvailable: false
    });

Step 5 — alert("Contractor assigned successfully!");
```

**Notes:**
- Job's `ContractorAssigned` is a Firestore `DocumentReference`, NOT a string ID. Anywhere a job's contractor is displayed, the admin code calls `getDoc(job.ContractorAssigned)` to resolve the name.
- Contractor's `Status` field (set here to "Unavailable") is *separate* from `AccountStatus`. They coexist.
- There is **no transaction** — if the second `updateDoc` fails, the job is left assigned to a contractor whose `Status` doesn't reflect it.
- The client-side filter (`Status === "Available"`) does not query Firestore — it iterates every contractor doc.

### B. Replying to Support Messages

**This feature does not exist.** There is no support chat, ticket system, message thread, or admin-reply flow anywhere in the admin portal. The sidebar navigation has only: Dashboard, Users, Contractors, Jobs, Reports, Service Management, Compliance Desk, Finance Desk.

A grep across all `.aspx` and `.cs` files for `chat|ticket|message|conversation|support|reply` produces zero feature matches (only the unrelated word "supports" appears once in `UserProfile.aspx`).

If the Flutter app already writes to a `SupportChats` collection, it is currently being **ignored by this admin portal** — admins have no way to read or respond.

### C. Other Notable Workflows

| Workflow | Page | Mechanism |
|---|---|---|
| Approve contractor verification | `ContractorProfile.aspx` | Sets `VerificationStatus: "approved"`, all entries in `ComplianceDocumentsMetadata` to status "approved", copies `SubmittedSelfieUrl` → `ApprovedProfileImageUrl` |
| Reject contractor verification | `ContractorProfile.aspx` | Modal with reason; sets `VerificationStatus: "rejected"`, all docs to "rejected" with `rejectionReason` |
| Mark withdrawal paid | `FinanceDesk.aspx` | `updateDoc({ Status: "completed" })` on the Withdrawals doc |
| Send monthly statement | `FinanceDesk.aspx` | `emailjs.send(service_vog61xa, template_r2d455i, { to_email, to_name, total_jobs, total_earnings, month_year })` |

---

## 5. Integration Gaps for Flutter App

### 5.1 Missing Support Chat Module — High Priority

If the Flutter app has a customer-support chat feature, **no admin counterpart exists**. You would need to add:
- New collection (e.g. `SupportChats/{chatId}/messages/{messageId}`)
- New `.aspx` page (e.g. `SupportChat.aspx`) with realtime listener via `onSnapshot`
- Sidebar nav entry in `Site1.Master`
- Likely a sidebar badge for unread admin-bound messages (mirroring Compliance/Finance)

### 5.2 ID Mapping Conflicts — High Priority

The Flutter app reportedly uses a `U***` (`U001`, `U002`...) friendly-ID mapping system. The admin portal currently has **two competing ID conventions**:

| Use case | Admin currently uses | Flutter likely uses |
|---|---|---|
| Navigate to a user's profile | Firestore doc ID (= Auth UID) — `UserProfile.aspx?id={uid}` | Friendly `UserID` (`U001`)? |
| Store user reference on a job | `Jobs.UserID` accepts **DocumentReference**, **path string `/Users/U004`**, OR **raw `U004`** — Dashboard handles all three (`Dashboard.aspx:131-141`) | Need to confirm which the Flutter app writes |
| Store contractor reference on a job | `Jobs.ContractorAssigned` is a `DocumentReference` | Need to confirm |
| Store contractor on an invoice | `JobInvoice.ContractorID` is used as a doc ID, not the friendly `C001` (`Dashboard.aspx:156`) | Risk of mismatch if Flutter writes `C001` |

**Decision needed:** pick ONE convention and migrate. Options:
- **(a)** Doc ID = Auth UID, friendly ID is display-only. *Simplest, but breaks readable URLs.*
- **(b)** Doc ID = friendly ID (`U001`), Auth UID stored as a field. *Requires admin-controlled ID minting; risks collisions if both apps mint IDs.*
- **(c)** Two-way mapping collection `IdMap/{friendlyId}` → `{ uid }`. *Extra read on every navigation.*

### 5.3 Field Casing & Schema Drift — Medium Priority

The admin portal already defends against multiple casings via fallback chains. Each new collision adds latent bugs. Standardize:

- `Contractor.Status` vs `Contractor.AccountStatus` — admin writes both; Flutter must read whichever it expects. Recommend deprecating `Status` (used only by AssignContractor) in favor of `AccountStatus` + a separate `Availability` flag.
- `Service.Status` / `Service.status` and `Service.BasePrice` / `Service.basePrice` — pick PascalCase or camelCase, migrate, remove the fallback reads.
- `Withdrawals.ContractorID` / `Withdrawals.contractorId` — same.

### 5.4 Hardcoded Configuration — Medium Priority

| Item | Location | Impact |
|---|---|---|
| Admin login credentials | `Login.aspx.cs:27-28` | `admin@irams.com` / `admin123`. Single shared admin. No password hash, no lockout. |
| Firebase config | `Site1.Master:113-122` | Including API key, project ID. Acceptable for client-side Firebase but means staging/prod can't be switched without recompiling. |
| EmailJS Public Key | `Site1.Master:27` | `eZ5Tkm-a1dK88H2ZD` |
| EmailJS Service ID + Template ID | `FinanceDesk.aspx` | `service_vog61xa`, `template_r2d455i`. Template variables hardcoded: `to_email, to_name, total_jobs, total_earnings, month_year` |
| Service slug generation | `ServiceAdd.aspx` | Slug derived from name client-side. Risk of collision if Flutter also creates services. |
| Contractor service-type checkboxes | `ContractorEdit.aspx` | 6 hardcoded options (Towing, Battery, Fuel, Tyre, Unlock, Repair). New service types added via `ServiceAdd` will NOT appear here. |
| Document type keys | `ContractorProfile.aspx` | 6 hardcoded keys (`IcFrontUrl`, `IcBackUrl`, `DrivingLicenceUrl`, `GdlLicenseUrl`, `VehicleGrantUrl`, `PuspakomUrl`). New doc types written by Flutter will be silently ignored. |
| Platform fee | `RevenueReports.aspx` | 10% — magic number, not driven by config |

### 5.5 Hard Delete Still in Use — Medium Priority

The Flutter app appears to follow a soft-delete model (preserve history). The admin portal has migrated **Contractors** to soft delete, but:

- `Users.aspx` and `UserProfile.aspx` still call `deleteDoc` directly. A user deletion in the admin would orphan their `Jobs` and `JobInvoice` records (lookups would fail with the "Unknown" fallback).
- `Services.aspx` still calls `deleteDoc`. Deleting a service used by historical invoices would similarly orphan them.

**Recommend:** add `IsDeleted: true` + `DeletedAt: serverTimestamp()` instead, and have all list pages filter out `IsDeleted == true` (mirroring `Contractors.aspx`).

### 5.6 No Server-Side Authorization on Firestore Writes — High Priority

Current Firestore rules:
```
allow read, write: if request.auth != null;
```

This grants **any anonymously authenticated session** (i.e., anyone who loads the admin URL — or the Flutter app — or any third party who knows the project ID) full read/write to every collection. The ASP.NET admin login (`Session["IsAdmin"]`) is enforced **only by the .aspx page redirect**, not by Firestore. A determined client could bypass `Login.aspx` entirely and write directly to Firestore using the published API key.

**Before launch, harden rules to:**
- Distinguish admin-only writes (verification approval, withdrawal status, service mgmt) from user/contractor writes
- Either issue Firebase Custom Tokens to the admin portal (signed by the service account already at `Key/iramsfyp-firebase-adminsdk-fbsvc-8b1f2659a5.json`), or move the privileged writes to C# code-behind using `FirebaseAdmin` SDK (already installed but unused)

### 5.7 Other Findings

- `JobDetails.aspx` initializes its **own** Firebase app instance instead of using `window.db` from the master page — duplicate init, separate auth state.
- The C# `Google.Cloud.Firestore` and `FirebaseAdmin` NuGet packages are installed and a service account JSON is committed to the repo, but **no C# code references them**. Either remove the dependencies or use them for the privileged writes called out in 5.6.
- No C# model classes for any Firestore entity. Schema is implicit in JS field-access patterns. If future admin features move to C#, models will need to be authored from scratch.

---

## 6. Recommended Reading

- `Site1.Master:108-139` — Firebase init pattern that every page depends on
- `AssignContractor.aspx:90-110` — canonical example of a write-touching-two-collections workflow
- `Dashboard.aspx:127-164` — defensive code for the multi-format `UserID` / `ContractorID` references; useful template for any new page
- `ContractorProfile.aspx` — most complex page; verification approval is the closest thing to a real workflow in this project

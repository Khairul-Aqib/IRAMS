# AdminPage Project Audit — Firestore Sync with Flutter Mobile App

## 1. Database Connection

**Client-side JavaScript SDK only — no C# Firestore usage.**

The `Google.Cloud.Firestore` NuGet package (v4.0.0) and `FirebaseAdmin` (v3.4.0) are installed and referenced in the `.csproj`, and a service account key exists at `Key/iramsfyp-firebase-adminsdk-fbsvc-8b1f2659a5.json`. However, **none of the C# code-behind files actually use them**. All Firestore reads/writes happen via the **Firebase JavaScript SDK v11.6.1** loaded in `<script type="module">` blocks on each `.aspx` page. The master page (`Site1.Master:78-109`) initializes Firebase client-side with `signInAnonymously()` and exposes `window.db` globally.

The C# code-behind files (`Contractors.aspx.cs`, `ContractorProfile.aspx.cs`, etc.) are essentially empty — they contain only empty `Page_Load` methods. The one exception is `ContractorEdit.aspx.cs` which has a `WebMethod` for saving uploaded images to the local `~/images` folder.

## 2. The Models

**There is no C# model/entity class for Contractor.** There are no `Models/` folder, no POCOs, no `[FirestoreData]` annotated classes anywhere. The Contractor "schema" is implicit in the JavaScript code. Based on the fields used across pages, the Firestore `Contractor` collection document has:

| Field | Used in | Present? |
|---|---|---|
| `FullName` | List, Profile, Edit | Yes |
| `Email` | List, Edit | Yes |
| `PhoneNumber` | List, Edit | Yes |
| `ServiceTypes` (array) | List, Edit | Yes |
| `AccountStatus` | List, Profile, Edit | Yes |
| **`VerificationStatus`** | List, Profile, Edit | **Yes** |
| `CompanyName` | Profile, Edit | Yes |
| `CompanyContactPhone` | Profile, Edit | Yes |
| `ProfileImage` | Profile, Edit | Yes |
| `ContractorID` | List | Yes |
| `TotalJobs` | List | Yes |
| `LastLogin` | List, Profile | Yes |
| **`activeJobId`** | — | **Not referenced** |
| **`DrivingLicenceUrl` / `IcFrontUrl`** | — | **Not referenced** |

`VerificationStatus` is present (with values Pending/Verified/Rejected). However, `activeJobId` and document URLs like `DrivingLicenceUrl` or `IcFrontUrl` are **not referenced anywhere** in this admin project.

## 3. The Verification Feature

**Partially exists — display and manual edit only, no dedicated approval workflow.**

- **Contractors list** (`Contractors.aspx:174`) shows a `VerificationStatus` column with color-coded badges (green=Verified, yellow=Pending, red=Rejected) and supports sorting by verification status.
- **Contractor Profile** (`ContractorProfile.aspx:83`) displays `VerificationStatus` as a read-only field.
- **Contractor Edit** (`ContractorEdit.aspx:136-141`) has a dropdown to manually change verification status to Pending/Verified/Rejected, which writes back to Firestore.
- **Documents section** on the profile page (`ContractorProfile.aspx:87-163`) is **entirely hardcoded sample data** — it does not read from Firestore. The "View" modal even says "Full document viewing feature coming soon in FYP2."

**There is no dedicated "Contractor Approvals" page**, no pending-verification queue, and no workflow to view uploaded documents (IC, driving licence, etc.) from Firestore and approve/reject them.

## Key Gaps to Address

1. **Move Firestore access to C#** (or keep JS but add proper security rules — anonymous auth is currently wide open)
2. **Create a C# Contractor model** with all fields the mobile app writes, including `activeJobId`, `DrivingLicenceUrl`, `IcFrontUrl`, etc.
3. **Build a real verification/approval page** that pulls document URLs from Firestore and lets the admin approve or reject with a reason

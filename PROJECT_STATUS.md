# IRAMS Project Status Report

**Project:** Intelligent Roadside Assistance Management System (IRAMS)
**Generated:** 2026-04-02
**Scope:** User App (Flutter), Contractor App (Flutter), Admin Panel (ASP.NET)

---

## 1. Project Overview

IRAMS is a Final Year Project (FYP) consisting of three applications that share a single Firebase/Firestore backend (`iramsfyp`):

| Application | Tech Stack | Location |
|---|---|---|
| **User App** | Flutter (Dart) | `C:/Users/khair/OneDrive/Documents/FlutterWork/UserApp/user_app/` |
| **Contractor App** | Flutter (Dart) | `C:/Users/khair/Downloads/FYP1-Contractor/FYP1-Contractor/contractor/` |
| **Admin Panel** | ASP.NET Web Forms + JS | `C:/Users/khair/source/repos/AdminPage/` |

---

## 2. User App (Flutter) — Implementation Status

**Navigation:** Uses `Navigator.pushReplacement()` for all drawer-linked pages; burger menu icon on every screen (GoRouter installed but unused)
**Theme:** Dark (#121212) with yellow accent (#FFFF00)

### Implemented Features

| Feature | Status | Notes |
|---|---|---|
| Login / Register | Done | Firebase Auth, email/password |
| Get Started Onboarding | Done | Splash-style page |
| Home Page with Mini Map | Done | Shows user location, dynamic `Hello, [fullName]!` greeting from Firestore, 4 quick actions |
| User Profile (View/Edit) | Done | Auto-fills from Firestore `Users` (PascalCase); saves `fullName`; syncs Auth displayName; `requires-recent-login` handling for password changes |
| Car List Page | Done | StreamBuilder on `Users/{uid}/Vehicles`; edit/delete per card; FAB to add; burger menu navigation |
| Add Car Form | Done | Brand, model, year, plate — persisted to `Users/{uid}/Vehicles`; redirects to Car List on save |
| Select Car | Done | Fetches user's vehicles from `Users/{uid}/Vehicles` subcollection in Firestore |
| Select Assistance Type | Done | Fully data-driven via Firestore `Services` collection; 6 types loaded dynamically |
| Dynamic Service Pricing | Done | BasePrice fetched from `Services` docs; no hardcoded prices (REQ-18) |
| Select Car Location (Map) | Done | Interactive map centered at Bukit Bintang |
| Battery/Tyre/Fuel flows | Done | Multi-step request flows with pricing |
| Payment Confirmation | Done | Shows service summary + total amount |
| Finding Assistance Screen | Done | Loading/waiting UI while matching contractor |
| Help On The Way | Done | Shows contractor info + ETA; Track My Driver navigates to ActiveJobMapPage |
| Emergency Call | Done | Calls hardcoded number +60123456789 |
| Messages Page | Done | StreamBuilder on Jobs filtered by UserID; per-job latest message from `Jobs/{id}/messages`; taps open real-time chat |
| Petrol Prices Page | Done | Malaysian fuel prices (RON 95, RON 97, Diesel) with station brand grid; dark theme with yellow accents |
| App Drawer Navigation | Polished | All secondary pages use `pushReplacement` + burger menu icon; sidebar shows real-time `fullName` and phone from Firestore; Firebase `signOut()` on logout |
| Service History | Done | Queries Jobs collection filtered by UserID; defensive null-safety for incomplete records; View Receipt for completed jobs |
| FCM Token Storage | Done | Stores token but no message handling |

### Stubbed / Incomplete Features

| Feature | Status | Issue |
|---|---|---|
| Knowledge Base | Partial | Page accessible via drawer; article detail tap is a TODO |
| About Us | Partial | Page accessible via drawer; "Visit Our Website" button is a TODO |
| Notifications Page | Stub | Referenced in drawer, minimal implementation |

### Hardcoded Data (needs Firestore integration)

- Emergency number: +60123456789
- Default map center: Bukit Bintang (3.1466, 101.7101)

### Defensive Programming

The history stream (`history.dart`) previously crashed with `Null check operator used on a null value` when Firestore job documents had missing fields (e.g. `DateCompleted` is null for cancelled/in-progress jobs, `TotalCost` absent on older records). This was resolved by:
- Null-safe timestamp parsing: `DateCompleted → DateRequested → Status text` fallback chain
- Currency safety: `(TotalCost ?? 0).toDouble()` with `RM —` display when zero
- Query corrected from `'UserId'` (camelCase) to `'UserID'` (PascalCase) to match the Firestore schema

---

## 3. Contractor App (Flutter) — Implementation Status

**Navigation:** GoRouter with auth state management
**Theme:** Dark (#0D0D0D) with yellow accent (#F6C000)

### Implemented Features

| Feature | Status | Notes |
|---|---|---|
| Login / Register | Done | Firebase Auth email/password |
| MFA Gate + SMS Enrollment | Done | Full Firebase MultiFactorAuth flow |
| Bottom Tab Navigation | Done | 3 tabs: Inbox, Map, Profile |
| Job Inbox | Done | Real-time Firestore stream, color-coded status badges |
| Job Details | Done | View details, call user, accept/reject job |
| Job Status Transitions | Done | Accepted → On The Way → In Progress → Completed |
| Active Job Map | Done | Real-time GPS tracking, OSRM polyline routing, contractor/user markers |
| Chat / Messaging | Done | Subcollection-based (Jobs/{id}/messages), real-time |
| Contractor Profile | Done | Display info, availability toggle (syncs to Firestore) |
| Job History | Done | Lists completed jobs with cost (RM) and location |
| Earnings Page | Done | Monthly breakdown from JobInvoice, service-type split |
| FCM Token Storage | Done | Stores in contractor doc |
| Location Service | Done | Continuous GPS, 10m filter, permission handling |
| Routing Service | Done | OSRM public API for polylines |

### Not Implemented

| Feature | Notes |
|---|---|
| Push Notification Handling | FCM token stored but no foreground/background message listeners |
| Profile Image Upload | Placeholder avatar only |
| Invoice Creation | Read-only; assumes admin creates invoices |
| Ratings / Reviews UI | Data model exists but no user-facing UI |

---

## 4. Admin Panel (ASP.NET Web Forms) — Implementation Status

**Framework:** .NET Framework 4.7.2
**Architecture:** ASP.NET Web Forms with client-side Firebase JS SDK (v11.6.1)
**Theme:** Dark UI with Tailwind CSS
**Auth:** Anonymous Firebase authentication (no admin login gate)

### Implemented Pages

| Page | Status | Key Features |
|---|---|---|
| Dashboard | Done | KPI cards (Users, Contractors, Jobs, Services), active jobs table (limit 10), recent invoices (limit 5) |
| Active Job List | Done | All non-completed jobs, contractor name lookups, status badges |
| Recent Job List | Done | All invoices with user/contractor names, cost in RM |
| Revenue Reports | Done | Total revenue, platform fee (10%), contractor earnings (90%), service breakdown, CSV export |
| Job Performance | Done | Completed/cancelled counts, avg completion time, user ratings, CSV export |
| Contractor Performance | Done | Acceptance/cancellation rates, earnings, ratings, service types, CSV export |
| User Activity | Done | User counts, registration tracking, service usage, CSV export |

### Not Implemented

| Feature | Notes |
|---|---|
| Admin Authentication | No login/authorization — anyone can access the dashboard |
| Contractor Verification UI | SRS requires admin to verify/approve contractors — no UI for this |
| Service Management CRUD | Sidebar link exists but no page |
| User Management CRUD | Sidebar link exists but no page |
| Job Management Actions | View-only — no ability to reassign, cancel, or modify jobs |
| Server-side Logic | All code-behind files (.aspx.cs) are empty; everything runs in client-side JS |

---

## 5. Firestore Collections in Use

| Collection | Used By | Fields |
|---|---|---|
| **`Users`** (PascalCase) | User App, Admin | email, firstName, lastName, phone, fullName, CreatedAt |
| **`Users/{id}/Vehicles`** | User App | Brand, Model, Year, PlateNumber, CreatedAt |
| **`Contractor`** (PascalCase) | All 3 apps | ContractorID, FullName, Email, PhoneNumber, CompanyName, AccountStatus, VerificationStatus, Status, Rating, TotalJobs, ServiceTypes, LastLocation (GeoPoint), fcmToken |
| **`Jobs`** (PascalCase) | All 3 apps | JobID, Status, ServiceType, TotalCost, UserLocation, UserGeo (GeoPoint), UserID (DocRef), ContractorAssigned (DocRef), UserName, UserPhone, Date* timestamps |
| **`Jobs/{id}/messages`** | User App, Contractor App | senderId, text, CreatedAt |
| **`JobInvoice`** (PascalCase) | Contractor App, Admin | JobID, UserID, ContractorID, ServiceType, TotalCost, PlatformFee, ContractorEarnings, PaymentMethod, Status, StartTime, CompletionTime, UserRating |
| **`Services`** (PascalCase) | User App, Admin | ServiceName, Description, BasePrice, Order |

All collections now use **PascalCase** naming consistently (`Users`, `Contractor`, `Jobs`, `JobInvoice`, `Services`).

---

## 6. TODO Comments Found

| File | Line | Comment |
|---|---|---|
| `user_app/lib/ui/pages/home/about_us.dart` | 80 | `// TODO: Open website` — low priority, cosmetic |
| `user_app/lib/ui/pages/home/knowledge_base.dart` | 103 | `// TODO: Navigate to article detail page` — low priority, cosmetic |

Both are minor UI polish items. The Contractor App and Admin Panel have **no TODO comments**.

---

## 7. SRS Gap Analysis — Unimplemented Requirements

Based on the SRS document (`C:/Users/khair/OneDrive/Documents/SRS Work.docx`):

### User App Gaps

| SRS Requirement | Status | Gap |
|---|---|---|
| REQ-2: Register with full name, email, phone, password | Done | Firebase Auth + Firestore profile creation with validation and error handling |
| REQ-5: Profile — modify email, password, telephone | Done | Auto-fills from Firestore; saves `fullName`; `requires-recent-login` error handling |
| REQ-6: Vehicle Asset Management (Add/Edit/Remove) | Done | Full CRUD via `Users/{uid}/Vehicles` — dedicated Car List page, edit (pre-filled), delete with confirmation |
| REQ-30: Service Transaction History | Done | `history.dart` queries Jobs filtered by UserID with null-safe field handling; View Receipt for completed jobs |
| Two-Way Chat with Contractor | Done | Messages page lists all job chats; real-time `Jobs/{id}/messages` subcollection; send/receive functional |
| Geospatial Location Confirmation | Done | Interactive map for service location |
| Invoicing and Remittance Display | Partial | Payment confirmation exists but no dynamic invoice generation |
| Real-time driver tracking | Done | Track My Driver navigates to ActiveJobMapPage with live contractor location |

### Admin Panel Gaps

| SRS Requirement | Status | Gap |
|---|---|---|
| Contractor Verification/Approval | Not Done | SRS: "Only Admin users shall verify and approve contractor accounts" |
| Admin Authentication | Not Done | No login gate — anyone can access |
| Invoice Access Control | Not Done | SRS: "Invoices restricted to respective Contractor" — currently public |
| Service Management CRUD | Not Done | Sidebar link only |
| User/Contractor Management | Not Done | View-only reports, no CRUD actions |

### Cross-Application Gaps

| SRS Requirement | Status | Gap |
|---|---|---|
| FPX Payment Gateway | Not Done | SRS requires FPX integration — no payment processing in any app |
| Password Hashing | Done | Handled by Firebase Auth |
| Real-Time Sync | Done | Firestore real-time listeners across all apps |
| Web Browser Compatibility | Done | Admin panel runs in browser |
| Mobile OS Compatibility | Done | Flutter apps target Android + iOS |

---

## 8. Summary Scorecard

| Component | Completion | Critical Gaps |
|---|---|---|
| **User App** | ~85% | FPX payment gateway not live; notifications stub |
| **Contractor App** | ~85% | Missing push notification handling, no profile image, no ratings UI |
| **Admin Panel** | ~60% | No admin auth, no contractor verification, no CRUD operations, empty code-behind |
| **Firestore Schema** | ~90% | Consistent PascalCase; no security rules visible |
| **SRS Coverage** | ~80% | FPX payment gateway integration pending; admin auth missing |

---

## 9. Priority Recommendations

1. **User App — Integrate FPX payment gateway** for live transactions (SRS requirement, highest priority)
2. **Admin Panel — Add admin authentication** (security requirement from SRS)
3. **Admin Panel — Build contractor verification** page (SRS compliance)
4. **User App — Push notification handling** for job status updates (FCM token already stored)
5. **Contractor App — Ratings/reviews UI** for completed jobs

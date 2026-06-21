# IRAMS User App — Integration Overview

> Reference document for the **Admin Web Dashboard** team. Describes the User App's services, navigation, messaging model, Firestore schema, and session/state management as of 2026-05-05.

---

## 1. Core Services

All services are file-scoped **singletons** (`MyService._()` + `static final instance`) — no DI container.

### `UserFirestoreService` — `lib/services/user_firestore_service.dart`
The single source of truth for user-side Firestore writes. **Recently migrated to a UID → U*** lookup model.**

| Concern | Details |
|---|---|
| Doc ID scheme | `Users/{customId}` where `customId` is a sequential `U001`, `U002`, … |
| **UID → U*** lookup** | `getCustomUserId()` runs `Users.where('authUid', == FirebaseAuth.uid).limit(1)` and **caches** the resolved ID in `_cachedCustomId` for the session. Cleared on logout via `clearCache()`. |
| ID generation | `generateNextUserId()` runs a Firestore **transaction** on `Metadata/Counters.lastUserNumber` to allocate the next `U***`. Called once during registration. |
| Job creation | `createJob()` writes `Jobs/{auto}` with `UserID: '/Users/U***'` (string path) **and** `ownerAuthUid` (raw FirebaseAuth UID) for security rules. |
| Vehicles | Owns `CarDetails`, `CarBrands` (read), and `VehicleRequests` (admin review queue). |
| Storage | Uploads vehicle-request photos to `vehicle_requests/{uid}_{epoch_ms}.jpg`. |

> ⚠️ **Admin Dashboard MUST query users via the `authUid` field — never assume `Users/{firebaseUid}` doc IDs.**

### `AuthService` — `lib/services/auth_service.dart`
Thin `ChangeNotifier` wrapper around `FirebaseAuth`. Notifies on `authStateChanges`. Calls `UserFirestoreService.instance.clearCache()` on `logout()`. Exposes `hasMfaEnrolled()` for MFA-aware flows.

### `InvoiceService` — `lib/services/invoice_service.dart`
Writes `JobInvoice/{auto}` after a **successful FPX payment**.

- **Dual-schema writes**: every doc carries both PascalCase keys (Admin) and camelCase aliases (Contractor App) — see §4.
- Computes `PlatformFee = TotalCost * 0.10` and `ContractorEarnings` automatically.
- Embeds the full FPX transaction snapshot under `FpxTransaction`.
- Generates a human receipt no.: `IRAMS-{epoch_ms}`.
- `markCompleted()` is invoked when the contractor flips a job to **Completed**.

### `ToyyibPayService` — `lib/services/toyyibpay_service.dart`
Bridges to **Cloud Functions in `asia-southeast1`** (sandbox).

| Callable | Purpose |
|---|---|
| `createToyyibPayBill` | Returns `{ billCode, paymentUrl, returnUrl }` for the WebView. |
| `verifyToyyibPayPayment` | Authoritative status check used when the webhook is delayed/missing — returns `Paid` / `Failed` / `Pending` / `NotFound` / `Error`. |

### `FirestoreService` — `lib/services/firestore_service.dart`
> ⚠️ **This is contractor-oriented logic** (email → `Contractor/{C***}` lookup, accept/reject jobs, contractor FCM token). Likely shared with the Contractor App. Admin Dashboard should ignore for user flows.

### Other Services
- `FcmService` — registers FCM token on the **contractor** doc (legacy/contractor-only).
- `LocationService`, `gps_utils`, `RoutingService` — geolocation + OSRM routing for the active-job map.

---

## 2. UI Navigation Flow

### Entry
- `main.dart` → **`LoginPage`** unconditionally (no auth gate; `LoginPage` itself routes to `HomePage` if a user is already signed in).
- `RegisterPage` → creates Firebase Auth account → `generateNextUserId()` → writes `Users/{U***}` → `GetStartedPage`.

### Home → Service Selection → Payment → Active Job

```
HomePage  (lib/ui/pages/home/homepage.dart)
  ├─ "Request Help"  ──►  SelectCarPage
  │                          └─►  SelectAssistancePage  ◄── streams `Services` collection
  │                                  │     (sorted by `Order` field; doc IDs are slugs)
  │                                  ├─ battery-replacement   ──►  BatteryOptionsPage
  │                                  ├─ tyre-change           ──►  TyreOptionsPage
  │                                  ├─ other-assistance      ──►  OtherAssistancePage
  │                                  ├─ fuel-delivery         ─┐
  │                                  ├─ towing                 ├──►  SelectCarLocationPage
  │                                  ├─ car-locksmith-service  │       └─►  (towing only) TowingDestinationPicker
  │                                  └─ minor-repair-service  ─┘            └─►  PaymentConfirmationPage
  │                                                                                └─►  FpxPaymentPage
  │                                                                                       └─►  ToyyibPayWebViewPage
  │                                                                                              └─►  PaymentVerificationPage
  │                                                                                                     └─►  ActiveJobTrackingPage
  │
  ├─ "Track Current Request"  ──►  ActiveJobTrackingPage  (when a non-Completed job exists)
  └─ "Emergency"              ──►  EmergencyCallPage
```

> **Service IDs are Firestore-driven**, not the literal `S001…S006` codes. Doc IDs in `Services` are slugs (e.g. `battery-replacement`). Map them via `Services/{slug}.ServiceName` for display.

### Active Job Detection (Homepage)
`HomePage._watchActiveJobs()` subscribes to:
```
Jobs.where('UserID', '==', '/Users/{customId}')
    .where('Status', whereIn: ['Pending','Accepted','OnTheWay','Arrived','InProgress','Completed'])
```
Diffs each doc's `Status` against `_lastSeenStatus[jobId]` and fires a local notification on transitions only.

### App Drawer
`AppDrawer` — Home, Messages, My Vehicles, History, Petrol Prices, Knowledge Base, About Us, Logout. Includes the "Chat with Us" button which **idempotently creates `SupportChats/{U***}`** before opening the support thread.

---

## 3. Messaging Engine

The User App handles **two parallel chat surfaces**, both surfaced through the same inbox.

### `MessageInboxPage` — `lib/ui/pages/messages/message_inbox_page.dart`
1. Resolves the user's `customId` (`U***`) by querying `Users` on `authUid`.
2. Subscribes to **two streams in parallel**:
   - **Job stream**: `Jobs.where('UserID', == '/Users/{customId}').orderBy('DateRequested', desc)`.
   - **Support stream**: `SupportChats/{customId}` doc snapshot.
3. `_filterJobs()` keeps a Job entry only if it has `ContractorAssigned` **or** at least one document in its `messages` subcollection (suppresses empty pending jobs).
4. `_mergeEntries()` merges `_JobEntry`s with at most one `_SupportEntry`, sorted by latest activity (`DateRequested` for jobs, `lastUpdated` for support).
5. Each `_InboxTile` opens its own `Jobs/{jobId}/messages` stream (limit 20, ordered by `CreatedAt desc`) to show a **live** preview + sender, falling back to a `contractors` lookup for the display name when `Job.ContractorName` is missing.

### `ChatConversationPage` — `lib/models/chat_detail.dart`
A single widget that branches on **mode** based on `jobId`:

| Aspect | Job Mode (`jobId != null`) | Support Mode (`.support()` ctor) |
|---|---|---|
| Messages collection | `Jobs/{jobId}/messages` | `SupportChats/{U***}/messages` |
| Field casing (write) | **PascalCase**: `Text`, `SenderId`, `CreatedAt` | **camelCase**: `text`, `senderId`, `isFromAdmin`, `createdAt` |
| Order key | `CreatedAt` | `createdAt` |
| Parent thread write | _none_ | Atomic batched write of `{ userId, lastMessage, lastUpdated }` to `SupportChats/{U***}` so admins can list threads efficiently |
| "Mine" detection | `senderId == FirebaseAuth.uid` | `!isFromAdmin` |
| Welcome card | hidden | pinned `_SystemWelcome` at top |

> **Reads tolerate either casing** (`data['text'] ?? data['Text']`) so admin tooling can choose one canonical case going forward without breaking the client.

---

## 4. Firestore Data Schema

Field names below are exactly what the User App writes — **match these on the Admin side**. Casing is mixed by design (PascalCase = Admin contract; camelCase = Contractor App contract; the InvoiceService writes both for compat).

### `Users/{U***}` — created by `RegisterPage`
| Field | Type | Notes |
|---|---|---|
| `authUid` | string | **Lookup key** → FirebaseAuth uid |
| `email` | string | |
| `firstName`, `lastName`, `fullName` | string | |
| `phone` | string | |
| `profileImageUrl` | string | optional |
| `CreatedAt` | Timestamp | server ts |

### `Metadata/Counters`
| Field | Type | Notes |
|---|---|---|
| `lastUserNumber` | int | Incremented in txn for next `U***` |

### `Jobs/{auto-id}` — created by `UserFirestoreService.createJob()`
| Field | Type | Notes |
|---|---|---|
| `UserID` | string | **Path string** `/Users/U***` (NOT a `DocumentReference`) |
| `ownerAuthUid` | string | FirebaseAuth uid — used by security rules |
| `CarPlate` | string | |
| `ServiceType` | string | display name, e.g. `Battery Replacement` |
| `Status` | string | one of: `Pending`, `Accepted`, `OnTheWay`, `Arrived`, `InProgress`, `Completed`, `Cancelled`, `Rejected`, `Awaiting Payment` |
| `TotalCost` | number | MYR |
| `UserLocation` | string | reverse-geocoded address |
| `CarLocation`, `UserGeo` | GeoPoint | |
| `UserName`, `UserPhone` | string | |
| `DateRequested` | Timestamp | |
| `DateCancelled`, `DateAccepted`, `DateOnTheWay`, `DateArrived`, `DateInProgress`, `DateCompleted`, `DateRejected` | Timestamp | written by status transitions |
| `ContractorAssigned` | DocumentReference | written by Contractor App / Admin |
| `ContractorName` | string | optional cache for inbox display |
| `ToyyibPayBillCode` | string | written by Cloud Function |
| `LastUpdated` | Timestamp | live car-location updates |

### `Jobs/{jobId}/messages/{auto-id}` — Job-mode chat
| Field | Type |
|---|---|
| `Text` | string |
| `SenderId` | string (FirebaseAuth uid) |
| `CreatedAt` | Timestamp |

### `SupportChats/{U***}` — Support-thread parent
| Field | Type |
|---|---|
| `userId` | string (`U***`) |
| `lastMessage` | string (≤80 chars preview) |
| `lastUpdated` | Timestamp |

### `SupportChats/{U***}/messages/{auto-id}` — Support-mode chat
| Field | Type |
|---|---|
| `text` | string |
| `senderId` | string (FirebaseAuth uid) |
| `isFromAdmin` | bool |
| `createdAt` | Timestamp |

### `JobInvoice/{auto-id}` — Dual-schema (Admin + Contractor App)
**Admin (PascalCase)**: `JobID`, `ServiceType`, `TotalCost`, `PlatformFee`, `ContractorEarnings`, `PaymentMethod` (`'FPX'`), `Status` (`'Completed'`), `UserID` (`/Users/U***`), `ContractorID`, `UserLocation`, `UserName`, `UserPhone`, `UserGeo`, `RequestedTime`, `StartTime`, `CompletionTime`, `UserRating`, `Cancellation`, `BatteryModel`, `Warranty`, `FpxTransaction`, `ReceiptNo`, `Currency` (`'MYR'`).
**Contractor App aliases (camelCase)**: `contractorId`, `totalCost`, `serviceType`, `createdAt`.

### `CarDetails/{CarID_{PLATE}}` — top-level vehicles
| Field | Type | Notes |
|---|---|---|
| `OwnerID` | string | `U***` |
| `Make`, `Model`, `Year`, `NumberPlate` | string | `Make = 'Undefined'` for unknown brands |
| `ManualBrandName`, `ManualModelName` | string | only for "Undefined" entries |
| `SupportTicketID` | string | links to a `VehicleRequests` doc |
| `CreatedAt` | Timestamp | |

### `CarBrands/{brand}` — read-only catalog
| Field | Type |
|---|---|
| `CarTypes` | array<string> (model names) |

### `VehicleRequests/{auto-id}` — admin review queue
| Field | Type |
|---|---|
| `brandName`, `modelName`, `requestType` (`'New Brand'` \| `'New Model'`) | string |
| `imageUrl` | string (Storage URL, optional) |
| `userId`, `ownerAuthUid` | string (both = FirebaseAuth uid) |
| `status` | string (`'Pending'`) |
| `createdAt` | Timestamp |

### `Services/{slug}` — service catalog (read-only by app)
| Field | Type | Notes |
|---|---|---|
| `ServiceName` | string | display label |
| `Description` | string | |
| `BasePrice` | string/number | parsed via `double.tryParse` |
| `Order` | number | sort order in grid |

---

## 5. State Management

The app **does not use a state-management library** (no Provider, Riverpod, Bloc).

| Concern | Mechanism |
|---|---|
| Service instances | Eager `static final instance = ServiceName._()` singletons (`UserFirestoreService`, `AuthService`, `FirestoreService`, `InvoiceService`, `ToyyibPayService`, `FcmService`). |
| Auth session | `FirebaseAuth.instance.currentUser` accessed directly throughout. `AuthService` extends `ChangeNotifier` and listens to `authStateChanges`, but **no widget observes it app-wide** — pages read `currentUser` ad-hoc. |
| Friendly UserID cache | `UserFirestoreService._cachedCustomId` (process-lifetime). Explicitly cleared on logout in both `AuthService.logout()` and the drawer's logout handler. |
| Reactive UI | `StatefulWidget` + `StreamBuilder`/`FutureBuilder` over Firestore queries. No global stores. |
| Routing | Imperative `Navigator.push` / `pushReplacement` / `pushAndRemoveUntil` — **no named routes**. |
| Notifications | Status transitions on the homepage's job-watching stream call `createJobNotification(...)` directly; no central event bus. |

> **Implication for Admin Dashboard**: there is no shared client cache to invalidate. Admin writes to Firestore propagate to the User App via the relevant `snapshots()` streams immediately.

---

## Quick Integration Checklist for the Admin Side

- [ ] Resolve users by `Users.where('authUid', ==, ...)` — **never** by `Users/{firebaseUid}`.
- [ ] When writing back to a Job, set `Status` to one of the canonical PascalCase values listed above and stamp the matching `Date*` field.
- [ ] When replying in support, write to `SupportChats/{U***}/messages` with `isFromAdmin: true` **and** update the parent doc's `lastMessage` + `lastUpdated` (the User App relies on this to surface the thread in the inbox).
- [ ] Cloud Functions (`createToyyibPayBill`, `verifyToyyibPayPayment`) are deployed in **`asia-southeast1`**.
- [ ] User-uploaded vehicle-request photos live under `vehicle_requests/` in Storage.

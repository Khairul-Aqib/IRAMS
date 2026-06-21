# IRAMS User Application — Feature & Business Logic Inventory

**Document Type:** Software Requirements Specification (SRS) — Feature Extraction  
**Project:** IRAMS (Intelligent Roadside Assistance Management System)  
**Platform:** Flutter 3.x (Dart SDK ^3.9.2) — Android & iOS  
**Backend:** Firebase (Firestore, Auth, Cloud Functions, Storage, Messaging)  
**Date Prepared:** 12 May 2026  
**Prepared By:** Technical Business Analyst (automated extraction from codebase)

---

## Table of Contents

1. [Module & Screen Inventory](#1-module--screen-inventory)
   - 1.1 [Authentication Module](#11-authentication-module)
   - 1.2 [Home & Dashboard Module](#12-home--dashboard-module)
   - 1.3 [Vehicle Management Module](#13-vehicle-management-module)
   - 1.4 [Service Request Module](#14-service-request-module)
   - 1.5 [Map & Location Module](#15-map--location-module)
   - 1.6 [Payment Module](#16-payment-module)
   - 1.7 [Messaging Module](#17-messaging-module)
   - 1.8 [Shared UI Components](#18-shared-ui-components)
2. [Core Business Logic & Rules](#2-core-business-logic--rules)
   - 2.1 [Job Status State Machine](#21-job-status-state-machine)
   - 2.2 [Payment & Billing Flow](#22-payment--billing-flow)
   - 2.3 [Pricing Rules](#23-pricing-rules)
   - 2.4 [Auto-Incrementing ID Scheme](#24-auto-incrementing-id-scheme)
   - 2.5 [Validation & Access Control](#25-validation--access-control)
   - 2.6 [Cancellation Policy](#26-cancellation-policy)
   - 2.7 [Rating & Feedback System](#27-rating--feedback-system)
   - 2.8 [Notification & Alert Rules](#28-notification--alert-rules)
   - 2.9 [Unread Message Tracking](#29-unread-message-tracking)
   - 2.10 [GPS Smoothing & ETA Estimation](#210-gps-smoothing--eta-estimation)
   - 2.11 [Vehicle Soft-Delete Pattern](#211-vehicle-soft-delete-pattern)
   - 2.12 [Dual-Casing Field Strategy](#212-dual-casing-field-strategy)
3. [Data Models & External Services](#3-data-models--external-services)
   - 3.1 [Firestore Collections](#31-firestore-collections)
   - 3.2 [Data Models](#32-data-models)
   - 3.3 [External Services & APIs](#33-external-services--apis)
   - 3.4 [Local Storage & Assets](#34-local-storage--assets)

---

## 1. Module & Screen Inventory

### 1.1 Authentication Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Login Page** | `auth/login.dart` | Email/password authentication via Firebase Auth. Displays contextual error messages for invalid credentials, disabled accounts, and network failures. Stamps `lastLogin` timestamp on the user's Firestore document upon successful sign-in. Navigates to the Get Started onboarding screen. |
| **Registration Page** | `auth/register.dart` | New user account creation. Validates all input fields (full name, email, phone, password, confirm password). Creates a Firebase Auth account, generates a unique `U***` user ID via a Firestore transaction on the `Metadata/Counters` document, and creates a `Users/{U***}` document with the user's profile fields, `authUid` link, `registrationDate`, and default `Status: 'Active'`. |

### 1.2 Home & Dashboard Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Get Started Page** | `home/get_started.dart` | Post-login onboarding splash screen. Displays IRAMS branding imagery and a single call-to-action button that navigates the user to the main Home Page. |
| **Home Page (Dashboard)** | `home/homepage.dart` | Central hub of the application. Displays a live mini-map showing the user's current GPS location rendered on OpenStreetMap tiles. Features a context-aware primary action button: shows "Request Help" when no active job exists, or "Track Current Request" when an ongoing job is detected. Includes an Emergency Call button, quick-access tiles for My Vehicles and History, and a real-time stream that monitors active jobs. Automatically creates in-app notifications when job status transitions occur. |
| **Notifications Page** | `home/notification.dart` | Displays all user notifications from the `Users/{U***}/notifications` subcollection, ordered by timestamp descending. Each notification shows a status-specific colour badge (e.g., green for Completed, red for Cancelled). Tapping a notification navigates to the Active Job Tracking page for ongoing jobs or the History page for completed/cancelled jobs. Also exports a `createJobNotification()` utility function consumed by the Home Page for status-transition alerts. |
| **User Profile Page** | `home/user_profile.dart` | Full profile management screen. Allows editing of display name and phone number. Supports profile photo changes via camera capture or gallery selection, uploaded to Firebase Storage at a user-specific path. Provides a password change flow that requires re-authentication before updating. Displays read-only fields: email address, custom user ID badge (`U***`), member-since date derived from `registrationDate`, and an account status badge (Active / Suspended / Banned). |
| **Emergency Call Page** | `home/emergency_call.dart` | Allows the user to store a personal emergency contact (name and phone number) on their `Users/{U***}` Firestore document. Provides a one-tap dial button that launches the device's phone dialler with the saved number pre-filled via the `url_launcher` package. |
| **Petrol Prices Page** | `home/petrol_prices.dart` | Static informational screen displaying current Malaysian fuel prices: RON 95 (RM 1.99, government-subsidised), RON 97 (RM 3.47), and Diesel (RM 3.35). Lists major Malaysian fuel station brands for reference. |
| **Knowledge Base Page** | `home/knowledge_base.dart` | Educational content hub presented as a grid of four illustrated guide cards: Dashboard Warning Lights, Car Accident Guide, Tyre Maintenance Tips, and How to Jumpstart a Car. Each card navigates to a dedicated detail page with step-by-step instructions. |
| **About Us Page** | `home/about_us.dart` | Company information page displaying IRAMS branding, mission statement, and an external link to the corporate website (carput.com.my) opened via `url_launcher`. |
| **History Page** | `home/history.dart` | Unified job history combining data from the `Jobs` and `JobInvoice` Firestore collections. Deduplicates completed jobs that have corresponding invoices. Presents three visual states per entry: Ongoing (with a "Track" action), Completed (with a "View Receipt" action), and Cancelled (greyed out). Receipt resolution follows a multi-fallback strategy: checks document fields (`ReceiptUrl`, `ReceiptPdfUrl`, `InvoiceUrl`, `pdfUrl`), then probes Firebase Storage paths (`receipts/{id}.pdf`, `invoices/{id}.pdf`). |

### 1.3 Vehicle Management Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Car List Page** | `home/car_list.dart` | Displays all vehicles owned by the current user, sourced from the `CarDetails` collection filtered by `OwnerID` and excluding soft-deleted records (`IsDeleted != true`). Each vehicle card shows brand, model, year, plate number, and colour. Provides swipe or tap actions for editing and deleting (soft-delete) vehicles. A floating action button navigates to the Add Car screen. |
| **Add / Edit Car Page** | `home/add_car.dart` | Vehicle registration and editing form with autocomplete-driven brand and model selection sourced from the `CarBrands` Firestore collection. If a user's vehicle brand or model is not in the catalogue, a "Can't find your car?" flow is available that creates a `VehicleRequests` entry (with optional photo upload to Firebase Storage) for administrative review, while simultaneously creating an "Undefined" vehicle record so the user is not blocked from requesting services. Document IDs follow the format `CarID_{plateNumber}`. |

### 1.4 Service Request Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Select Car Page** | `requestJob/select_car.dart` | First step of the service request flow. Lists all of the user's registered vehicles from the `CarDetails` collection. Selecting a vehicle passes it forward to the Select Assistance screen. Includes an inline option to add a new vehicle without leaving the flow. |
| **Select Assistance Page** | `requestJob/select_assistance.dart` | Service catalogue grid populated from the Firestore `Services` collection (filtered by `Status: 'Active'`, sorted by `Order` field). Available service types: Battery Replacement, Tyre Change, Fuel Delivery, Towing, Car Locksmith Service, Minor Repair Service, and Other Assistance. Each service tile shows an icon, name, and base price. Tapping a tile routes to the appropriate options page or directly to the location selection screen, passing the base price forward. |
| **Battery Options Page** | `requestJob/battery_options.dart` | Battery model selection for the Battery Replacement service. Presents three options with fixed pricing: NS40ZL (RM 185), NS60L (RM 220), and DIN65L (RM 350). Total cost is calculated as `basePrice + batteryPrice`. Includes a "Chat with Us" fallback link for unlisted battery types, routing to Support Chat. |
| **Battery Types Page** | `requestJob/battery_types.dart` | Secondary battery brand/tier selection. Offers three branded batteries: MUTLU (RM 209, 3-month warranty), CENTURY ROADMASTER (RM 225, 15-month warranty), and CAMEL PLUS (RM 249, 18-month warranty). Navigates to the Payment Confirmation screen with the selected battery details and total cost. |
| **Tyre Options Page** | `requestJob/tyre_options.dart` | Tyre service variant selection. Two options: Spare Tyre Change (flat RM 60, navigates to `SelectCarLocationPage`) or Towing to Workshop (flat RM 160, navigates to `CarTowMapPage` for destination selection). |
| **Fuel Options Page** | `requestJob/fuel_options.dart` | Fuel delivery configuration. Features a segmented control for fuel type (RON 95 / RON 97 / Diesel), a numeric input field for fuel budget (RM 5 – RM 100 range with real-time validation), and a flat RM 25 delivery fee. Total is displayed as `fuelAmount + deliveryFee` in a sticky bottom bar. Input validation prevents non-numeric entries and amounts exceeding the RM 100 cap. |
| **Other Assistance Page** | `requestJob/other_assisstance.dart` | Informational screen for service types not covered by the standard catalogue. Directs the user to the Support Chat for personalised assistance and quotation. |
| **Help On The Way Page** | `requestJob/help_ontheway.dart` | Contractor dispatch confirmation screen. Displays the assigned contractor's name, vehicle details, and profile photo. Polls the contractor's `LastLocation` field every 10 seconds, computes Haversine distance to the user's location, and displays a live ETA estimate. Provides a "Call Driver" button and a "Track My Driver" button that navigates to the full Active Job Tracking map view. |

### 1.5 Map & Location Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Select Car Location Page** | `map/select_car_location.dart` | Breakdown location selection. The user places a map pin to mark their vehicle's location, with reverse geocoding providing a human-readable address. For towing services, a secondary destination picker is enabled. Towing cost is dynamically calculated as `basePrice + (distance_km × RM 5/km)`. On confirmation, navigates to the Payment Confirmation screen with the computed total and location data. |
| **Location Picker Page** | `map/location_picker_page.dart` | Reusable full-screen map picker. Returns a `PickedLocation` object containing latitude/longitude coordinates, a formatted address name, and a Firestore-compatible `GeoPoint`. Used by both the breakdown location and towing destination flows. |
| **Towing Destination Picker** | `map/towing_destination_picker.dart` | Specialised map interface for selecting a towing drop-off point. Uses a centre-pin paradigm where the user pans the map to position the destination. |
| **Active Job Tracking Page** | `map/active_job_tracking.dart` | Primary real-time job monitoring screen. Implements a Firestore `StreamBuilder` on the `Jobs/{jobId}` document for live status updates. Streams the assigned contractor's GPS coordinates, renders an OSRM-sourced route polyline on the map, and displays a live ETA banner. Features a collapsible bottom sheet with full job details. Handles all job states with state-specific UI: Awaiting Payment (verify payment button), Pending (cancel button with reason picker), Accepted/On The Way (contractor info card with call and message actions), Arrived (snackbar notification), In Progress (progress indicator), Completed (star-rating dialog or acknowledgement). |
| **Active Job Map Page** | `map/active_job_map_page.dart` | FlutterMap-based map rendering component with GPS smoothing (exponential moving average), route polyline overlay, and ETA text overlay. Supports two operational modes: `activeJob` (live contractor tracking) and `selectCarLocation` (static pin placement). |
| **Car Tow Map Page** | `map/car_tow_map.dart` | Map interface for selecting a towing destination. Employs a centre-pin design where the user scrolls the map to set the desired drop-off location. Displays the selected address and calculates the towing distance. |

### 1.6 Payment Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Payment Confirmation Page** | `payment/payment_confirmation.dart` | Order summary and review screen. Displays service type, battery/fuel details (if applicable), pickup location, towing destination and distance (if applicable), and the estimated total cost. A "Proceed to Payment" button advances to the FPX Payment page. |
| **FPX Payment Page** | `payment/fpx_payment_page.dart` | Payment method selection screen offering FPX (online banking) or Cash payment. Enforces a phone number gate: if the user's profile lacks a phone number, payment is blocked and the user is redirected to the User Profile page. **FPX flow:** Creates a Job document with `Status: 'Awaiting Payment'` using an auto-incremented `J***` ID, calls the `createToyyibPayBill` Cloud Function, and opens the ToyyibPay WebView. **Cash flow:** Creates a Job document with `Status: 'Pending'` and navigates directly to the Active Job Tracking page. |
| **ToyyibPay WebView Page** | `payment/toyyibpay_webview_page.dart` | Embedded WebView that loads the ToyyibPay payment gateway URL. Intercepts navigation to the pre-configured return URL to detect payment completion and redirects to the Payment Verification page. Includes a confirm-exit dialog on back-press to prevent accidental payment abandonment. |
| **Payment Verification Page** | `payment/payment_verification_page.dart` | Post-payment status polling screen. Listens to the `Jobs/{jobId}` Firestore document for a `PaymentStatus: 'Paid'` field (set server-side by the ToyyibPay callback webhook). Displays a loading indicator during the wait. After 20 seconds, reveals a manual "Check Status" button that calls the `verifyToyyibPayPayment` Cloud Function. Enforces a hard timeout at 3 minutes, after which the user is prompted to contact support. |
| **Digital Receipt Page** | `payment/digital_receipt_page.dart` | On-screen payment receipt displaying: receipt number (`IRAMS-{epoch}`), FPX transaction ID, buyer bank name (mapped from bank code), payment amount breakdown (subtotal, 15% platform fee, total), date/time, and payment status. Provides a "Back to Home" navigation button. |
| **Receipt Viewer Page** | `payment/receipt_viewer_page.dart` | PDF receipt viewer powered by the Syncfusion PDF Viewer. Resolves the PDF URL through a multi-source fallback: checks the direct `pdfUrl` parameter, then queries `JobInvoice` document fields (`ReceiptUrl`, `ReceiptPdfUrl`, `InvoiceUrl`, `pdfUrl`), and finally probes Firebase Storage paths (`receipts/{id}.pdf`, `invoices/{id}.pdf`). Supports downloading the PDF to the device's local documents directory via Dio with a progress indicator. |

### 1.7 Messaging Module

| Screen | File | Primary Functions |
|--------|------|-------------------|
| **Message Inbox Page** | `messages/message_inbox_page.dart` | Consolidated message inbox listing all active conversations. Combines job-specific chats (from `Jobs/{jobId}/messages`) and the Support Chat thread. Each conversation tile displays the latest message preview, timestamp, and an unread message indicator. |
| **Chat Conversation Page** | `models/chat_detail.dart` | Dual-mode real-time chat interface. **Job Chat mode:** Reads and writes messages to `Jobs/{jobId}/messages`, displays the contractor's selfie as their avatar, and tracks read status via `lastReadAt`. **Support Chat mode:** Operates on `SupportChats/{userId}/messages`, uses batch writes to atomically update both the message subcollection and the parent thread's `lastMessage`/`lastUpdated` fields. Both modes support text messages with automatic scroll-to-bottom, sender-side alignment, and timestamp display. |
| **Support Chat Page** | `messages/support_chat_page.dart` | Thin wrapper that instantiates `ChatConversationPage` in Support mode. Accessible from the drawer's "Chat with Us" button and from the Other Assistance service flow. |

### 1.8 Shared UI Components

| Component | File | Purpose |
|-----------|------|---------|
| **App Drawer** | `models/app_drawer.dart` | Application-wide navigation drawer. Displays a real-time profile header (avatar, name, phone) driven by a Firestore stream on the `Users/{U***}` document. Contains the "Chat with Us" button (with automatic `SupportChats` thread creation), main navigation items (Home, Messages, My Vehicles, History, Petrol Prices, Knowledge Base), About Us, and a Logout action. Messages item includes a live unread count badge. |
| **Unread Menu Button** | `models/unread_menu_button.dart` | Reusable hamburger menu icon button with a red unread message count badge, driven by the `UnreadMessagesService` singleton. Placed in the app bar of every main screen for consistent drawer access and unread visibility. |

---

## 2. Core Business Logic & Rules

### 2.1 Job Status State Machine

The Job lifecycle is governed by a ten-state finite state machine. Each state maps to a specific user-facing UI treatment on the Active Job Tracking screen.

```
┌──────────────────┐
│  AwaitingPayment  │──── (FPX payment initiated, waiting for gateway callback)
└────────┬─────────┘
         │ PaymentStatus = 'Paid' (server-side webhook)
         ▼
┌──────────────────┐
│     Requested     │──── (Job visible to contractors for acceptance)
│    ("Pending")    │
└────────┬─────────┘
         │                          ┌──────────────┐
         ├─── Contractor declines ──►   Rejected    │
         │                          └──────────────┘
         │                          ┌──────────────┐
         ├─── User cancels ────────►   Cancelled    │
         │                          └──────────────┘
         ▼
┌──────────────────┐
│     Accepted      │──── (Contractor assigned; user sees contractor info)
└────────┬─────────┘
         ▼
┌──────────────────┐
│    On The Way     │──── (Contractor en route; live GPS tracking + ETA)
└────────┬─────────┘
         ▼
┌──────────────────┐
│     Arrived       │──── (Contractor at scene; snackbar notification)
└────────┬─────────┘
         ▼
┌──────────────────┐
│   In Progress     │──── (Service being performed)
└────────┬─────────┘
         ▼
┌──────────────────┐
│    Completed      │──── (Job finished; rating dialog presented)
└──────────────────┘
```

**State-specific UI behaviours:**

| State | User-Facing UI | Available Actions |
|-------|---------------|-------------------|
| Awaiting Payment | Loading spinner with "Verifying payment" message | "Check Status" button (after 20s timeout), hard timeout at 3 minutes |
| Requested / Pending | "Looking for a contractor" indicator | Cancel job (with mandatory reason selection) |
| Accepted | Contractor info card (name, phone, vehicle) | Call contractor, send message |
| On The Way | Live map with contractor marker, route polyline, ETA banner | Call contractor, send message |
| Arrived | Snackbar: "Your contractor has arrived" | Call contractor, send message |
| In Progress | Progress indicator with "Service in progress" label | Call contractor, send message |
| Completed | Star-rating dialog (1–5 stars) with optional text feedback | Submit rating, skip rating |
| Cancelled | Cancellation summary with reason | Return to Home |
| Rejected | Rejection notice | Return to Home or request again |

**Wire Format:** Status values are serialised to Firestore in PascalCase strings (e.g., `"Awaiting Payment"`, `"On The Way"`, `"In Progress"`). The `JobStatus` enum handles bidirectional mapping.

### 2.2 Payment & Billing Flow

The application supports two payment methods, each following a distinct flow:

**FPX (Online Banking) Flow:**
1. User reviews order on the Payment Confirmation screen.
2. Phone number gate: system verifies the user's profile contains a phone number; blocks proceeding if absent.
3. A Job document is created in Firestore with `Status: 'Awaiting Payment'` and an auto-incremented `J***` ID.
4. The `createToyyibPayBill` Firebase Cloud Function (region: `asia-southeast1`) is invoked, returning a `billCode` and `paymentUrl`.
5. The `toyyibPayBillCode` is written to the Job document.
6. A WebView opens the ToyyibPay payment gateway URL.
7. Upon return URL interception, the app navigates to the Payment Verification screen.
8. The verification screen listens to the Job document for `PaymentStatus: 'Paid'` (set by a server-side webhook).
9. A manual fallback calls `verifyToyyibPayPayment` Cloud Function after a 20-second timeout.
10. Hard timeout at 3 minutes prompts the user to contact support.
11. On successful verification, a `JobInvoice` document is created and a digital receipt is displayed.

**Cash Payment Flow:**
1. User reviews order on the Payment Confirmation screen.
2. Phone number gate (same as FPX).
3. A Job document is created with `Status: 'Pending'` (skips the awaiting payment state).
4. User is navigated directly to the Active Job Tracking screen.

**Invoice Generation:**
- Invoices are created via `InvoiceService.createInvoice()` upon successful payment.
- Each invoice receives a unique receipt number in the format `IRAMS-{millisecondsSinceEpoch}`.
- The platform fee (15%) is calculated and stored alongside contractor earnings.
- FPX transaction details are embedded within the invoice document.

### 2.3 Pricing Rules

| Service | Pricing Model | Calculation |
|---------|--------------|-------------|
| Battery Replacement | Base price + battery model price | Base from `Services` collection + fixed per-model surcharge (NS40ZL: RM 185, NS60L: RM 220, DIN65L: RM 350) |
| Battery (Branded Tier) | Fixed total | MUTLU: RM 209, CENTURY ROADMASTER: RM 225, CAMEL PLUS: RM 249 |
| Tyre — Spare Change | Flat rate | RM 60 |
| Tyre — Towing | Flat rate | RM 160 |
| Fuel Delivery | Fuel budget + flat delivery fee | User-entered amount (RM 5–100) + RM 25 delivery fee |
| Towing | Base price + distance surcharge | Base from `Services` collection + (distance in km × RM 5/km) |
| Other services | Base price from catalogue | Loaded from `Services` collection `BasePrice` field |
| **Platform Fee** | **15% of total cost** | Applied at invoice creation: `totalCost × 0.15` |
| **Contractor Earnings** | **85% of total cost** | `totalCost − platformFee` |

**Currency:** All monetary values are denominated in Malaysian Ringgit (MYR).

### 2.4 Auto-Incrementing ID Scheme

The system uses a custom sequential ID scheme managed via Firestore transactions on the `Metadata/Counters` document. This ensures human-readable, collision-free identifiers across all three applications (User App, Contractor App, Admin Panel).

| Entity | Format | Example | Generator |
|--------|--------|---------|-----------|
| User | `U` + zero-padded 3+ digit number | `U001`, `U042`, `U999` | `UserFirestoreService.generateNextUserId()` |
| Job | `J` + zero-padded 3+ digit number | `J001`, `J150` | Created in `fpx_payment_page.dart` via Firestore transaction |
| Contractor | `C` + zero-padded 3+ digit number | `C001`, `C015` | Managed by Admin Panel / Contractor App |

**Mechanism:** A Firestore transaction atomically reads the current counter value from `Metadata/Counters`, increments it, writes the new value back, and returns the formatted ID. This prevents duplicate IDs under concurrent access.

**Cross-referencing:** Job documents store user references as Firestore path strings (e.g., `"/Users/U042"`), enabling lookups across collections. The `UserID` field on a Job always contains this path format.

### 2.5 Validation & Access Control

**Authentication:**
- All application screens beyond Login and Registration require an authenticated Firebase Auth session.
- Session state is checked via `FirebaseAuth.instance.currentUser`.
- The drawer and service flows gracefully handle null user states with fallback UI.

**Phone Number Gate:**
- The FPX Payment page enforces that the user's profile contains a valid phone number before payment can proceed.
- If missing, the user is redirected to the User Profile page with a prompt to add their phone number.

**Input Validation Rules:**
- Registration: All fields required; email format validated; password minimum length enforced; password and confirm-password must match.
- Fuel amount: Must be numeric, greater than RM 0, maximum RM 100. Non-numeric input shows an inline error; the "Next" button is disabled while validation fails.
- Vehicle plate number: Used as part of the document ID (`CarID_{plate}`), ensuring uniqueness per vehicle.
- Emergency contact: Phone number format validated before saving.

**Password Change:**
- Requires re-authentication with the current password before `updatePassword` is called, following Firebase Auth security requirements.

**Account Status:**
- User documents carry a `Status` field with possible values: `Active`, `Suspended`, `Banned`.
- Status is displayed as a badge on the User Profile page. Enforcement of suspended/banned states is handled server-side.

### 2.6 Cancellation Policy

Users may cancel a job only while it is in the **Requested / Pending** state (before contractor acceptance). The cancellation flow requires:

1. Selection of a mandatory cancellation reason from a predefined list:
   - "Wait time too long"
   - "Found another provider"
   - "Price too high"
   - "Changed my mind"
   - "Other" (free-text input required)
2. The selected reason and optional details are written to the `Cancellation` field on the Job document.
3. Job status is updated to `Cancelled`.
4. A notification is generated for the user's notification feed.

**Constraint:** Cancellation is not available once a contractor has accepted the job (status beyond Pending).

### 2.7 Rating & Feedback System

Upon job completion, the user is presented with a rating dialog:

- **Star Rating:** 1 to 5 stars (required to submit).
- **Text Feedback:** Optional free-form comment field.
- **Storage:** Rating and feedback are written to the `Jobs/{jobId}` document fields (`UserRating`, and feedback text).
- **Skip Option:** Users may dismiss the dialog without rating; a "Thanks" acknowledgement is shown instead.
- The `JobInvoice` document also contains a `UserRating` field (initially `null`, updated when the user submits a rating).

### 2.8 Notification & Alert Rules

**In-App Notifications:**
- Notifications are stored in the `Users/{U***}/notifications` subcollection.
- The `createJobNotification()` function is triggered by the Home Page's job stream when a status transition is detected.
- Each notification records: job ID, new status, a human-readable message, and a server timestamp.
- Notifications display status-specific colour badges (green for Completed, yellow for On The Way, red for Cancelled, etc.).
- Tapping a notification navigates to the Active Job Tracking page (for active jobs) or the History page (for completed/cancelled jobs).

**Push Notifications:**
- Firebase Cloud Messaging (FCM) is integrated via the `FcmService`.
- The service requests notification permissions from the OS, retrieves the device FCM token, and stores it on the user's Firestore document.
- Push notification delivery is handled server-side via Firebase Cloud Functions.

**Unread Indicator:**
- A red dot badge is displayed on the notification bell icon in the drawer header. This is a static indicator (always visible) rather than count-driven.

### 2.9 Unread Message Tracking

The `UnreadMessagesService` is a singleton that maintains a real-time count of unread messages across all conversations. It operates as follows:

1. **Subscription Sources:**
   - The user's `Users/{U***}` document (for `lastReadAt` timestamps per chat key).
   - All Jobs where `UserID` matches the current user (for job chat threads).
   - Per-job `messages` subcollections (for message timestamps).
   - `SupportChats/{userId}/messages` subcollection (for support thread messages).

2. **Calculation:** For each conversation (job chat or support thread), the service compares the latest message timestamp against the corresponding `lastReadAt` value. Messages newer than the last read timestamp are counted as unread.

3. **Consumption:** The total unread count is exposed via a `ValueNotifier<int>`, consumed by:
   - The `_MessagesDrawerItem` widget (badge on the Messages menu item in the drawer).
   - The `UnreadMenuButton` widget (badge on the hamburger menu icon in the app bar).

4. **Read Marking:** When the user opens a conversation, the `lastReadAt` for that chat key is updated on the `Users/{U***}` document, causing the count to recompute and the badges to update in real time.

### 2.10 GPS Smoothing & ETA Estimation

**GPS Smoothing (Exponential Moving Average):**
- The `GpsSmoothing` class applies an EMA filter with `alpha = 0.3` to incoming GPS coordinates.
- A spike guard rejects any coordinate update whose Haversine distance from the last accepted position exceeds 500 metres, preventing map jumps caused by GPS noise or tunnel exits.
- Smoothed coordinates are used for the contractor's marker position on the tracking map.

**Haversine Distance Calculation:**
- Standard spherical geometry formula computing great-circle distance between two lat/lng pairs.
- Used for: towing distance pricing, contractor proximity detection, and ETA calculation.

**ETA Estimation:**
- Assumed average speed: 35 km/h.
- Detour factor: 1.4× (accounts for road routing vs. straight-line distance).
- Formula: `ETA (seconds) = (haversineDistance × detourFactor) / averageSpeed`.
- Display: Formatted as "X min" or "X hr Y min" via the `formatEta()` utility.

**OSRM Route Polyline:**
- When available, the `RoutingService` fetches the actual road route from the OSRM public demo server.
- Returns a `RouteResult` containing: decoded polyline coordinates, total duration, and total distance.
- The polyline is rendered on the map as the contractor's route to the user.
- Falls back to a legacy polyline method if the OSRM request fails.

### 2.11 Vehicle Soft-Delete Pattern

Vehicles are never physically removed from the `CarDetails` collection. Instead:

- The `deleteVehicle()` method sets an `IsDeleted: true` flag on the document.
- All vehicle list queries filter with `IsDeleted != true`, excluding soft-deleted records from the UI.
- This preserves referential integrity for historical job records that reference the vehicle.

### 2.12 Dual-Casing Field Strategy

To maintain compatibility across the three applications in the IRAMS ecosystem, Firestore documents (particularly `JobInvoice`) store fields in two naming conventions simultaneously:

| Convention | Consumer | Example Fields |
|------------|----------|---------------|
| **PascalCase** | Admin Panel (web) | `TotalCost`, `ServiceType`, `ContractorID`, `UserID`, `PaymentMethod`, `Status`, `UserLocation`, `RequestedTime`, `CompletionTime` |
| **camelCase** | Contractor App (mobile) | `totalCost`, `serviceType`, `contractorId`, `userId`, `paymentMethod`, `status`, `userLocation`, `requestedTime`, `completionTime`, `createdAt` |

Both sets of fields are written atomically in a single Firestore `add()` or `set(merge: true)` operation, ensuring consistency. This dual-write pattern is classified as an audit-mandated mirror.

---

## 3. Data Models & External Services

### 3.1 Firestore Collections

| Collection | Document ID Format | Purpose | Key Fields |
|------------|--------------------|---------|------------|
| **Users** | `U***` (auto-increment) | User profiles and account data | `authUid`, `fullName`, `email`, `phone`, `profileImageUrl`, `registrationDate`, `lastLogin`, `Status`, `emergencyContactName`, `emergencyContactPhone` |
| **Users/{id}/notifications** | Auto-generated | In-app notification feed | `jobId`, `status`, `message`, `timestamp` |
| **Jobs** | `J***` (auto-increment) | Service requests and job lifecycle | `JobID`, `ServiceType`, `Status`, `TotalCost`, `UserID` (path ref), `UserLocation`, `UserLatLng`, `UserName`, `UserPhone`, `ContractorAssigned` (path ref), `DateRequested`, `DateCompleted`, `PaymentStatus`, `PaymentMethod`, `toyyibPayBillCode`, `UserRating`, `Cancellation` |
| **Jobs/{id}/messages** | Auto-generated | Per-job chat messages | `senderId`, `text`, `timestamp`, `senderRole` |
| **JobInvoice** | Auto-generated | Payment invoices and receipts | Dual-cased fields (see §2.12): `JobID`/`jobId`, `TotalCost`/`totalCost`, `PlatformFee`/`platformFee`, `ContractorEarnings`/`contractorEarnings`, `ServiceType`/`serviceType`, `FpxTransaction`/`fpxTransaction`, `ReceiptNo`/`receiptNo`, `Currency`/`currency` |
| **Contractor** | `C***` (auto-increment) | Contractor profiles and availability | `uid`, `fullName`, `email`, `phone`, `isAvailable`, `rating`, `LastLocation` (GeoPoint), `fcmToken` |
| **CarDetails** | `CarID_{plateNumber}` | User-registered vehicles | `OwnerID`, `Brand`, `Model`, `Year`, `PlateNumber`, `Colour`, `IsDeleted` |
| **CarBrands** | Brand name | Vehicle brand and model catalogue | `Models` (array of model names) |
| **VehicleRequests** | Auto-generated | User-submitted requests for missing vehicle brands/models | `userId`, `brand`, `model`, `imageUrl`, `status`, `timestamp` |
| **Services** | Service slug (e.g., `fuel-delivery`) | Service catalogue and pricing | `Name`, `BasePrice`, `Icon`, `Status`, `Order`, `Description` |
| **SupportChats** | `U***` (user's custom ID) | Support conversation threads | `userId`, `lastMessage`, `lastUpdated` |
| **SupportChats/{id}/messages** | Auto-generated | Support chat messages | `senderId`, `text`, `timestamp`, `senderRole` |
| **Metadata/Counters** | `Counters` (singleton) | Auto-increment counters for ID generation | `userCount`, `jobCount`, `contractorCount` |

### 3.2 Data Models

**Job Model (`models/job.dart`)**
| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Firestore document ID (`J***`) |
| `jobId` | String | Human-readable job identifier |
| `serviceType` | String | Service category label |
| `status` | JobStatus (enum) | Current lifecycle state (10 possible values) |
| `totalCost` | double | Total amount charged to the user |
| `userLocation` | String | Human-readable breakdown address |
| `userRef` | String | Firestore path to user document (`/Users/U***`) |
| `contractorAssignedRef` | String? | Firestore path to contractor document |
| `dateRequested` | DateTime? | Timestamp of job creation |
| `dateCompleted` | DateTime? | Timestamp of job completion |
| `userLatLng` | LatLng? | GPS coordinates of the breakdown location |
| `userName` | String | User's full name (denormalised) |
| `userPhone` | String | User's phone number (denormalised) |
| `toyyibPayBillCode` | String? | ToyyibPay bill reference code |

**Contractor Model (`models/contractor.dart`)**
| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | Firestore document ID (`C***`) |
| `fullName` | String | Contractor's display name |
| `email` | String | Contractor's email address |
| `phone` | String | Contractor's phone number |
| `isAvailable` | bool | Current availability status |
| `rating` | double | Average user rating |
| `lastLocation` | LatLng? | Most recent GPS position (converted from GeoPoint) |

**FPX Transaction Model (`models/payment.dart`)**
| Field | Type | Description |
|-------|------|-------------|
| `fpxTxnId` | String | FPX gateway transaction identifier |
| `sellerOrderNo` | String | Merchant order reference |
| `fpxTxnStatus` | FpxTxnStatus (enum) | Transaction outcome: `successful`, `failed`, `pending` |
| `buyerBankId` | String | Buyer's bank institution code |
| `buyerName` | String | Buyer's name as returned by FPX |
| `amount` | String | Transaction amount |
| `txnCurrency` | String | Currency code (always `MYR`) |
| `debitAuthCode` | String | Bank authorisation code |

### 3.3 External Services & APIs

| Service | Provider | Integration Method | Purpose |
|---------|----------|--------------------|---------|
| **Firebase Authentication** | Google | Firebase SDK (`firebase_auth`) | Email/password user authentication, session management, password reset |
| **Cloud Firestore** | Google | Firebase SDK (`cloud_firestore`) | Primary database for all application data; real-time streams via `snapshots()` |
| **Firebase Cloud Functions** | Google | Firebase SDK (`cloud_functions`, region: `asia-southeast1`) | Server-side ToyyibPay bill creation and payment verification |
| **Firebase Cloud Storage** | Google | Firebase SDK (`firebase_storage`) | Profile photo uploads, vehicle request images, receipt PDF storage |
| **Firebase Cloud Messaging** | Google | Firebase SDK (`firebase_messaging`) | Push notification delivery to user devices |
| **ToyyibPay** | ToyyibPay Sdn Bhd | Cloud Functions proxy → ToyyibPay REST API | Malaysian FPX online banking payment gateway (sandbox environment) |
| **OSRM** | OpenStreetMap community | HTTP REST API via Dio (`router.project-osrm.org`) | Driving route polyline, distance, and duration calculation |
| **OpenStreetMap Tiles** | OpenStreetMap Foundation | Tile URL template via `flutter_map` | Map tile rendering for location selection and job tracking screens |
| **Google Maps** | Google | `google_maps_flutter` package | Map rendering (migration in progress from FlutterMap; dependency present but partial adoption) |
| **Geolocator** | Flutter community | `geolocator` package | Device GPS position retrieval, location permission handling, continuous location streaming (10m distance filter) |
| **Geocoding** | Flutter community | `geocoding` package | Reverse geocoding (coordinates → human-readable address) |
| **Syncfusion PDF Viewer** | Syncfusion | `syncfusion_flutter_pdfviewer` package | In-app PDF receipt rendering with zoom, scroll, and page navigation |

### 3.4 Local Storage & Assets

| Resource | Type | Purpose |
|----------|------|---------|
| `assets/map_style_dark.json` | JSON asset | Custom dark-mode map styling for Google Maps rendering |
| `lib/images/Logo.png` | Image asset | Primary IRAMS logo (also used as app launcher icon) |
| `lib/images/Logo_2.png` | Image asset | Secondary logo variant used in app bar headers |
| `lib/images/LoginBG.jpg` | Image asset | Login page background image |
| `lib/images/getStartedBG.jpg` | Image asset | Get Started page background image |
| `lib/images/car_bg.jpg` | Image asset | Decorative automotive background |
| `lib/images/admin1.jpg` | Image asset | About Us page team/branding image |
| Device documents directory | Local filesystem | Download destination for PDF receipts (via `path_provider`) |

---

*End of Feature & Business Logic Inventory. This document was extracted programmatically from the IRAMS User Application codebase and reflects the implemented state of the system as of 12 May 2026.*

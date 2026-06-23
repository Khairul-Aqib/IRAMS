<%@ Page Title="User Profile" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="UserProfile.aspx.cs" Inherits="AdminPage.UserProfile" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    User Profile
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Users Management &gt; <span id="profileUserNameTitle">User</span></h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8">

        <!-- top section -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-6 mb-8">

            <!-- left avatar and name -->
            <div class="flex items-center gap-5">
                <div class="w-24 h-24 rounded-full bg-gray-600 overflow-hidden">
                    <img id="profileImage"
                         src="https://via.placeholder.com/150"
                         alt="Profile"
                         class="w-full h-full object-cover" />
                </div>
                <div>
                    <h2 id="profileFullName" class="text-2xl font-bold mb-1">Full Name</h2>
                    <p class="text-sm text-gray-400">
                        Last Login:
                        <span id="profileLastLogin">-</span>
                    </p>
                </div>
            </div>

            <!-- right actions -->
            <div class="flex gap-3">
                <asp:HyperLink ID="lnkSuspendUser" runat="server"
                    CssClass="px-4 py-2 rounded-lg bg-yellow-500 hover:bg-yellow-600 text-black font-semibold text-sm cursor-pointer">
                    Suspend
                </asp:HyperLink>

                <asp:HyperLink ID="lnkDeleteUser" runat="server"
                    CssClass="px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white font-semibold text-sm cursor-pointer">
                    Delete
                </asp:HyperLink>

                <asp:HyperLink ID="lnkEditUser" runat="server"
                    CssClass="px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white font-semibold text-sm cursor-pointer">
                    Edit
                </asp:HyperLink>
            </div>
        </div>

        <!-- details grid -->
        <div class="grid md:grid-cols-2 gap-6 mb-8">
            <div>
                <p class="text-sm font-semibold mb-1">Full Name</p>
                <div class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm" id="detailFullName">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Email Address</p>
                <div class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm" id="detailEmail">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Phone Number</p>
                <div class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm" id="detailPhone">-</div>
            </div>

            <div>
                <p class="text-sm font-semibold mb-1">Account Status</p>
                <div class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm" id="detailStatus">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Emergency Contact Name</p>
                <div class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm" id="detailEmergencyName">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Emergency Contact Phone</p>
                <div class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm" id="detailEmergencyPhone">-</div>
            </div>
        </div>

        <!-- Simple job history table placeholder -->
        <h3 class="text-lg font-semibold mb-3">Service Requested</h3>
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Job ID</th>
                        <th class="py-3 px-4 text-left">Service Type</th>
                        <th class="py-3 px-4 text-left">User Location</th>
                        <th class="py-3 px-4 text-left">Total Cost</th>
                        <th class="py-3 px-4 text-left">Payment Method</th>
                        <th class="py-3 px-4 text-left">Date</th>
                        <th class="py-3 px-4 text-left">Status</th>
                    </tr>
                </thead>
                <tbody id="userJobsTableBody">
                    <tr>
                        <td colspan="7" class="py-4 px-4 text-center text-gray-400">
                            Loading jobs...
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>

    </div>

    <div id="deleteUserModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
            <h3 class="text-lg font-semibold mb-2">Deactivate User?</h3>
            <p class="text-sm text-gray-600 mb-6">
                Are you sure you want to deactivate this user? Their account will be locked, but their data and job history will be preserved.
            </p>
            <div class="flex justify-end gap-3">
                <button type="button"
                        id="btnCancelDeleteUser"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300">
                    Cancel
                </button>
                <button type="button"
                        id="btnConfirmDeleteUser"
                        class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600">
                    Confirm
                </button>
            </div>
        </div>
    </div>

    <div id="suspendUserModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">

            <h3 id="suspendModalTitle" class="text-lg font-semibold mb-2">Suspend User?</h3>

            <p id="suspendModalText" class="text-sm text-gray-600 mb-6">
                User will immediately lose access and won't be able to sign in. Are you sure you want to suspend this user?
            </p>

            <div class="flex justify-end gap-3">
                <button type="button"
                        id="btnCancelSuspendUser"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300">
                    Cancel
                </button>

                <button type="button"
                        id="btnConfirmSuspendUser"
                        class="px-4 py-2 rounded-lg bg-green-500 text-white hover:bg-green-600">
                    Confirm
                </button>
            </div>

        </div>
    </div>

    <script type="module">
        import {
            doc,
            getDoc,
            updateDoc,
            collection,
            query,
            where,
            limit,
            getDocs
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        let urlIdParam = null;     // raw value from ?id= (auth UID per new architecture)
        let userDocId = null;      // resolved Users/{docId} (e.g. "U001")
        let userDocRef = null;
        let userStatus = "Active";
        let suspendAction = "suspend";

        function formatDateTime(value) {
            if (!value) return "";

            if (typeof value.toDate === "function") {
                const d = value.toDate();
                return formatDateToString(d);
            }

            const d = new Date(value);
            if (!isNaN(d.getTime())) {
                return formatDateToString(d);
            }

            return value.toString();
        }

        function formatDateToString(d) {
            const day = String(d.getDate()).padStart(2, "0");
            const month = String(d.getMonth() + 1).padStart(2, "0");
            const year = d.getFullYear();
            const hours = String(d.getHours()).padStart(2, "0");
            const minutes = String(d.getMinutes()).padStart(2, "0");
            return `${day}/${month}/${year} ${hours}:${minutes}`;
        }

        function formatDateOnly(value) {
            if (!value) return "";

            let d;
            if (typeof value.toDate === "function") {
                d = value.toDate();
            } else {
                d = new Date(value);
            }

            if (!isNaN(d.getTime())) {
                const day = String(d.getDate()).padStart(2, "0");
                const month = String(d.getMonth() + 1).padStart(2, "0");
                const year = d.getFullYear();
                return `${day}/${month}/${year}`;
            }

            return value.toString();
        }

        document.addEventListener("firebase-auth-ready", async () => {
            const params = new URLSearchParams(window.location.search);
            urlIdParam = params.get("id");

            if (!urlIdParam) {
                alert("No user id specified.");
                window.location.href = "Users.aspx";
                return;
            }

            const resolved = await resolveUserDoc(urlIdParam);
            if (!resolved) {
                alert("User not found.");
                window.location.href = "Users.aspx";
                return;
            }

            userDocId = resolved.id;
            userDocRef = doc(db, "Users", userDocId);

            await loadUserProfile(resolved.data);
            await loadUserJobs();

            setupDeleteModal();
            setupSuspendModal();

            // set Edit button link (forwards the same id param the page received)
            const editLink = document.getElementById("<%= lnkEditUser.ClientID %>");
            editLink.href = "UserEdit.aspx?id=" + urlIdParam;
        });

        // Resolve the Users document. Per the new ID architecture, the URL `id` is
        // the Firebase Auth UID, and the U*** document is found via the `authUid` field.
        // Falls back to a direct doc lookup so legacy callers (which passed the doc id
        // like "U001") continue to work.
        async function resolveUserDoc(idParam) {
            const q = query(
                collection(db, "Users"),
                where("authUid", "==", idParam),
                limit(1)
            );
            const qSnap = await getDocs(q);
            if (!qSnap.empty) {
                const d = qSnap.docs[0];
                return { id: d.id, data: d.data() };
            }

            const directRef = doc(db, "Users", idParam);
            const directSnap = await getDoc(directRef);
            if (directSnap.exists()) {
                return { id: directSnap.id, data: directSnap.data() };
            }
            return null;
        }

        async function loadUserProfile(preloaded) {
            try {
                let u = preloaded;
                if (!u) {
                    const snap = await getDoc(userDocRef);
                    if (!snap.exists()) {
                        alert("User not found.");
                        window.location.href = "Users.aspx";
                        return;
                    }
                    u = snap.data();
                }

                // Field-name variants: the mobile user app uses camelCase
                // (profileImageUrl, accountStatus, ...) while the admin app's
                // edit form writes PascalCase. Read the first present value
                // so a single page works for both data sources.
                const fullName       = u.fullName || u.FullName || "";
                const email          = u.email || u.Email || "";
                const phone          = u.phone || u.PhoneNumber || u.Phone || "";
                const status         = u.Status || u.AccountStatus || u.accountStatus || "";
                // Read camelCase (mobile-app source of truth) first, fall back to
                // PascalCase / legacy variants. Reversing this order is the fix for
                // stale Emergency Contact values shadowing fresh mobile updates.
                const emergencyName  = u.emergencyContactName || u.emergencyName || u.EmergencyName || "";
                const emergencyPhone = u.emergencyContactPhone || u.emergencyPhone || u.EmergencyPhone || "";
                const lastLogin      = u.LastLogin || u.lastLogin || null;
                const profileImage   = u.profileImageUrl || "";

                document.getElementById("profileUserNameTitle").textContent = fullName || "User";
                document.getElementById("profileFullName").textContent = fullName || "N/A";
                document.getElementById("profileLastLogin").textContent = formatDateTime(lastLogin) || "N/A";

                document.getElementById("detailFullName").textContent = fullName || "N/A";
                document.getElementById("detailEmail").textContent = email || "N/A";
                document.getElementById("detailPhone").textContent = phone || "N/A";
                document.getElementById("detailStatus").textContent = status || "N/A";
                document.getElementById("detailEmergencyName").textContent = emergencyName || "N/A";
                document.getElementById("detailEmergencyPhone").textContent = emergencyPhone || "N/A";

                // Profile image: full URLs (mobile app's Storage download URL or
                // any external host) are used as-is; bare file names are treated
                // as files served from the admin's local images/ folder.
                const imgEl = document.getElementById("profileImage");
                if (profileImage) {
                    let imageSrc = profileImage;
                    if (!imageSrc.startsWith("http://") && !imageSrc.startsWith("https://") && !imageSrc.startsWith("data:")) {
                        imageSrc = imageSrc.replace("~/", "");
                        if (!imageSrc.startsWith("images/")) imageSrc = "images/" + imageSrc;
                    }
                    imgEl.src = imageSrc;
                } else {
                    imgEl.src = "images/default-avatar.png";
                }
                // If the URL fails to load (broken Storage path, deleted file, etc.),
                // swap in the default avatar so we don't show a broken-image icon.
                imgEl.onerror = () => { imgEl.onerror = null; imgEl.src = "images/default-avatar.png"; };

                userStatus = status || "Active";
                updateSuspendButtonUI();
            } catch (err) {
                console.error("Error loading profile:", err);
                alert("Failed to load profile.");
            }
        }

        async function loadUserJobs() {
            try {
                const tbody = document.getElementById("userJobsTableBody");

                const jobsRef = collection(db, "Jobs");
                const allJobsSnapshot = await getDocs(jobsRef);

                // Match against both the resolved doc id (e.g. "U001") and the auth UID
                // from the URL, so jobs are found regardless of which format the
                // mobile app stored on the Job document.
                const candidates = [userDocId, urlIdParam].filter(Boolean);
                const refPaths = candidates.map(c => `Users/${c}`);

                let matchingJobs = [];

                allJobsSnapshot.forEach((docSnap) => {
                    const job = docSnap.data();
                    const jobId = docSnap.id;

                    if (job.UserID && typeof job.UserID === 'object' && job.UserID.path) {
                        if (refPaths.includes(job.UserID.path)) {
                            matchingJobs.push({ id: jobId, data: job });
                        }
                    }
                    else if (typeof job.UserID === 'string') {
                        const v = job.UserID;
                        const stripped = v.includes('/') ? v.split('/').pop() : v;
                        if (candidates.includes(stripped)) {
                            matchingJobs.push({ id: jobId, data: job });
                        }
                    }
                });
                
                console.log("Matching jobs found:", matchingJobs.length);
                
                if (matchingJobs.length === 0) {
                    tbody.innerHTML = `
                        <tr>
                            <td colspan="7" class="py-4 px-4 text-center text-gray-400">
                                No jobs found for this user (Check browser console for debug info)
                            </td>
                        </tr>
                    `;
                    return;
                }

                // Clear loading message
                tbody.innerHTML = "";

                // Build table rows
                matchingJobs.forEach(({ id: jobId, data: job }) => {
                    const row = document.createElement("tr");
                    row.className = "border-t border-[#333] hover:bg-[#252525]";

                    // Determine status badge color
                    let statusClass = "bg-gray-600";
                    const status = (job.Status || "").toLowerCase();
                    if (status === "completed") {
                        statusClass = "bg-green-600";
                    } else if (status === "pending") {
                        statusClass = "bg-yellow-600";
                    } else if (status === "in progress") {
                        statusClass = "bg-blue-600";
                    } else if (status === "cancelled") {
                        statusClass = "bg-red-600";
                    }

                    row.innerHTML = `
                        <td class="py-3 px-4">${jobId || "-"}</td>
                        <td class="py-3 px-4">${job.ServiceType || "-"}</td>
                        <td class="py-3 px-4">${job.UserLocation || "-"}</td>
                        <td class="py-3 px-4">RM ${(parseFloat(job.TotalCost) || 0).toFixed(2)}</td>
                        <td class="py-3 px-4">${job.PaymentMethod || "-"}</td>
                        <td class="py-3 px-4">${formatDateOnly(job.DateRequested) || "-"}</td>
                        <td class="py-3 px-4">
                            <span class="px-2 py-1 rounded text-xs ${statusClass}">
                                ${job.Status || "-"}
                            </span>
                        </td>
                    `;

                    tbody.appendChild(row);
                });

            } catch (err) {
                console.error("Error loading jobs:", err);
                const tbody = document.getElementById("userJobsTableBody");
                tbody.innerHTML = `
                    <tr>
                        <td colspan="7" class="py-4 px-4 text-center text-red-400">
                            Error loading jobs. Check console for details.
                        </td>
                    </tr>
                `;
            }
        }

        function updateSuspendButtonUI() {
            const btn = document.getElementById("<%= lnkSuspendUser.ClientID %>");
            if (!btn) return;

            const lower = (userStatus || "").toLowerCase();

            if (lower === "active") {
                // Show Suspend
                btn.textContent = "Suspend";
                btn.dataset.action = "suspend";
                btn.className =
                    "px-4 py-2 rounded-lg bg-yellow-500 hover:bg-yellow-600 text-black font-semibold text-sm cursor-pointer";
            } else {
                // Treat all non-active as Suspended
                btn.textContent = "Activate";
                btn.dataset.action = "activate";
                btn.className =
                    "px-4 py-2 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-white font-semibold text-sm cursor-pointer";
            }
        }

        // --- Delete modal setup ---
        function setupDeleteModal() {
            const modal = document.getElementById("deleteUserModal");
            const btnCancel = document.getElementById("btnCancelDeleteUser");
            const btnConfirm = document.getElementById("btnConfirmDeleteUser");
            const deleteBtn = document.getElementById("<%= lnkDeleteUser.ClientID %>");

            deleteBtn.addEventListener("click", (e) => {
                e.preventDefault();
                modal.classList.remove("hidden");
            });

            btnCancel.addEventListener("click", () => {
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                try {
                    await updateDoc(userDocRef, {
                        IsDeleted: true,
                        Status: "Deactivated"
                    });
                    alert("User has been deactivated.");
                    window.location.href = "Users.aspx";
                } catch (err) {
                    console.error("Error deactivating user:", err);
                }
            });
        }

        // --- Suspend/Activate modal setup ---
        function setupSuspendModal() {
            const modal = document.getElementById("suspendUserModal");
            const btnCancel = document.getElementById("btnCancelSuspendUser");
            const btnConfirm = document.getElementById("btnConfirmSuspendUser");
            const titleEl = document.getElementById("suspendModalTitle");
            const textEl = document.getElementById("suspendModalText");
            const btn = document.getElementById("<%= lnkSuspendUser.ClientID %>");

            btn.addEventListener("click", (e) => {
                e.preventDefault();

                suspendAction = btn.dataset.action || "suspend";

                if (suspendAction === "suspend") {
                    titleEl.textContent = "Suspend User?";
                    textEl.textContent =
                        "User will immediately lose access and won't be able to sign in. Are you sure you want to suspend this user?";
                } else {
                    titleEl.textContent = "Activate User?";
                    textEl.textContent =
                        "User will regain access to their account. Are you sure you want to activate this user?";
                }

                modal.classList.remove("hidden");
            });

            btnCancel.addEventListener("click", () => {
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                try {
                    const newStatus = suspendAction === "suspend" ? "Suspended" : "Active";
                    await updateDoc(userDocRef, { Status: newStatus });

                    userStatus = newStatus;
                    document.getElementById("detailStatus").textContent = newStatus;

                    updateSuspendButtonUI();

                    modal.classList.add("hidden");
                } catch (err) {
                    console.error("Error updating user status:", err);
                }
            });
        }
    </script>

</asp:Content>

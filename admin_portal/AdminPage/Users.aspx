<%@ Page Title="Users Management" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="Users.aspx.cs" Inherits="AdminPage.Users" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Users Management
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-8 text-yellow-400">Users Management</h1>

    <!-- USERS LIST CARD -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">

        <!-- Header row -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Users List</h2>

            <!-- Right sort and search -->
            <div class="flex items-center gap-3">

                <!-- Show deactivated toggle -->
                <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer select-none">
                    <input type="checkbox" id="showDeactivated" checked
                           class="accent-yellow-400 w-4 h-4" />
                    Show deactivated
                </label>

                <!-- Sort by -->
                <div>
                    <select id="sortUsers"
                            class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm">
                        <option value="name-asc">Name (A–Z)</option>
                        <option value="name-desc">Name (Z–A)</option>
                        <option value="id-asc">User ID (U001→)</option>
                        <option value="status-active">Status (Active first)</option>
                        <option value="regdate-desc">Registration (Newest)</option>
                        <option value="lastlogin-desc">Last Login (Newest)</option>
                    </select>
                </div>

                <!-- Search -->
                <div class="relative">
                    <input id="userSearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-64"
                           placeholder="Search (Name, Email, or ID)" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>
            </div>
        </div>

        <!-- TABLE -->
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">User ID</th>
                        <th class="py-3 px-4 text-left">Full Name</th>
                        <th class="py-3 px-4 text-left">Email Address</th>
                        <th class="py-3 px-4 text-left">Phone Number</th>
                        <th class="py-3 px-4 text-left">Status</th>
                        <th class="py-3 px-4 text-left">Registration Date</th>
                        <th class="py-3 px-4 text-left">Last Login</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="usersTableBody">
                </tbody>
            </table>
        </div>

    </div>

    <!-- DELETE / REACTIVATE USER MODAL (text adapts at open time) -->
    <div id="deleteUserModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
            <h3 id="userActionTitle" class="text-lg font-semibold mb-2">Deactivate User?</h3>
            <p id="userActionBody" class="text-sm text-gray-600 mb-6">
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

    <!-- users JS -->
    <script type="module">
        import {
            collection,
            getDocs,
            onSnapshot,
            updateDoc,
            doc,
            serverTimestamp
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        function formatDateTime(value) {
            if (!value) return "";

            // Firestore Timestamp object → has .toDate()
            if (typeof value.toDate === "function") {
                const d = value.toDate();
                return formatDateToString(d);
            }

            // If it’s already a JS Date or ISO string
            const d = new Date(value);
            if (!isNaN(d.getTime())) {
                return formatDateToString(d);
            }

            // Fallback: just return as-is
            return value.toString();
        }

        function formatDateToString(d) {
            // the time format dd/MM/yyyy HH:mm (which its 24-hour)
            const day = String(d.getDate()).padStart(2, "0");
            const month = String(d.getMonth() + 1).padStart(2, "0");
            const year = d.getFullYear();

            const hours = String(d.getHours()).padStart(2, "0");
            const minutes = String(d.getMinutes()).padStart(2, "0");

            return `${day}/${month}/${year} ${hours}:${minutes}`;
        }

        let users = [];
        let currentSearch = "";
        let currentSort = "name-asc";
        let showDeactivated = true;

        let userToDelete = null;       // Firestore doc id
        let pendingAction = "deactivate"; // or "reactivate"

        document.addEventListener("firebase-auth-ready", () => {
            loadUsers();
            setupSearch();
            setupSort();
            setupShowDeactivatedToggle();
            setupDeleteModal();
        });

        function setupShowDeactivatedToggle() {
            const cb = document.getElementById("showDeactivated");
            cb.addEventListener("change", () => {
                showDeactivated = cb.checked;
                applyUserFiltersAndSort();
            });
        }

        function loadUsers() {
            const tbody = document.getElementById("usersTableBody");
            tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            onSnapshot(collection(db, "Users"), (snap) => {
                users = [];
                snap.forEach(docSnap => {
                    users.push({ id: docSnap.id, ...docSnap.data() });
                });
                applyUserFiltersAndSort();
            }, (err) => {
                console.error("Error loading users:", err);
                tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-red-400'>Failed to load users.</td></tr>";
            });
        }

        function applyUserFiltersAndSort() {
            let list = users.slice();

            if (!showDeactivated) {
                list = list.filter(u => u.IsDeleted !== true);
            }

            if (currentSearch) {
                list = list.filter(u =>
                    (u.fullName || "").toLowerCase().includes(currentSearch) ||
                    (u.email || "").toLowerCase().includes(currentSearch) ||
                    (u.id || "").toLowerCase().includes(currentSearch)
                );
            }

            list = sortUsers(list);

            renderUsers(list);
        }

        function sortUsers(list) {
            const getName = u => (u.fullName || "").toLowerCase();
            const getIdNum = u => {
                // if U001 is 1, if U023 then its 23
                const id = u.id || "";
                const num = parseInt(id.substring(1));
                return isNaN(num) ? 0 : num;
            };
            const getJobs = u => parseInt(u.TotalJobs || "0") || 0;
            const getRegDate = u => {
                const v = u.CreatedAt;
                if (v && typeof v.toDate === "function") {
                    return v.toDate().getTime();
                }
                const d = new Date(v || "1970-01-01");
                return d.getTime();
            };
            const getStatus = u => (u.Status || "").toLowerCase();
            const getLastLogin = u => {
                // Mobile (Flutter) writes `lastLogin` (camelCase); older admin
                // writes used `LastLogin`. Read whichever is present.
                const v = u.LastLogin || u.lastLogin;
                if (v && typeof v.toDate === "function") {
                    // Firestore Timestamp
                    return v.toDate().getTime();
                }
                const d = new Date(v || "1970-01-01");
                return d.getTime();
            };

            switch (currentSort) {
                case "name-desc":
                    return list.sort((a, b) => getName(b).localeCompare(getName(a)));
                case "id-asc":
                    return list.sort((a, b) => getIdNum(a) - getIdNum(b));
                case "jobs-desc":
                    return list.sort((a, b) => getJobs(b) - getJobs(a));
                case "regdate-desc":
                    return list.sort((a, b) => getRegDate(b) - getRegDate(a));
                case "lastlogin-desc":
                    return list.sort((a, b) => getLastLogin(b) - getLastLogin(a));
                case "status-active":
                    return list.sort((a, b) => {
                        const aVal = getStatus(a) === "active" ? 0 : 1;
                        const bVal = getStatus(b) === "active" ? 0 : 1;
                        if (aVal !== bVal) return aVal - bVal;
                        return getName(a).localeCompare(getName(b));
                    });
                case "name-asc":
                default:
                    return list.sort((a, b) => getName(a).localeCompare(getName(b)));
            }
        }

        function renderUsers(list) {
            const tbody = document.getElementById("usersTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-gray-400'>No users found.</td></tr>";
                return;
            }

            for (const u of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                const status = (u.Status || "").toString();
                const isActive = status.toLowerCase() === "active";
                const statusColor = isActive ? "bg-emerald-500" : "bg-red-500";

                const regDateText = formatDateTime(u.CreatedAt);
                const lastLoginText = formatDateTime(u.LastLogin || u.lastLogin);

                const isDeleted = u.IsDeleted === true;
                const actionLabel = isDeleted ? "Reactivate" : "Deactivate";
                const actionType  = isDeleted ? "reactivate" : "deactivate";
                const actionColor = isDeleted ? "text-emerald-400" : "text-red-400";

                tr.innerHTML = `
                    <td class="py-3 px-4">${u.id || "—"}</td>
                    <td class="py-3 px-4">${u.fullName || "—"}</td>
                    <td class="py-3 px-4">${u.email || "—"}</td>
                    <td class="py-3 px-4">${u.phone || "—"}</td>
                    <td class="py-3 px-4">
                        ${status
                            ? `<span class="inline-block px-3 py-1 rounded-full text-xs font-semibold text-white ${statusColor}">${status}</span>`
                            : "—"}
                    </td>
                    <td class="py-3 px-4">${regDateText || "—"}</td>
                    <td class="py-3 px-4">${lastLoginText || "—"}</td>
                    <td class="py-3 px-4">
                        <div class="flex gap-2 text-xs">
                            <a href="UserProfile.aspx?id=${u.id}" class="text-blue-400 hover:underline">View</a>
                            <button type="button"
                                class="${actionColor} hover:underline user-action-btn"
                                data-id="${u.id}"
                                data-action="${actionType}">
                                ${actionLabel}
                            </button>
                        </div>
                    </td>
                `;
                tbody.appendChild(tr);
            }

            // attach actions
            document.querySelectorAll(".user-action-btn").forEach(btn => {
                btn.addEventListener("click", () => {
                    userToDelete = btn.dataset.id;
                    pendingAction = btn.dataset.action;
                    openDeleteUserModal();
                });
            });
        }

        function setupSearch() {
            const input = document.getElementById("userSearch");
            input.addEventListener("input", () => {
                currentSearch = input.value.toLowerCase();
                applyUserFiltersAndSort();
            });
        }

        function setupSort() {
            const select = document.getElementById("sortUsers");
            select.addEventListener("change", () => {
                currentSort = select.value;
                applyUserFiltersAndSort();
            });
        }

        // Modal serves both deactivation and reactivation. The text and the
        // confirm-button colour are swapped at open time based on pendingAction.
        function setupDeleteModal() {
            const modal = document.getElementById("deleteUserModal");
            const btnCancel = document.getElementById("btnCancelDeleteUser");
            const btnConfirm = document.getElementById("btnConfirmDeleteUser");

            btnCancel.addEventListener("click", () => {
                userToDelete = null;
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                if (!userToDelete) return;
                try {
                    if (pendingAction === "reactivate") {
                        await updateDoc(doc(db, "Users", userToDelete), {
                            IsDeleted: false,
                            Status: "Active"
                        });
                    } else {
                        await updateDoc(doc(db, "Users", userToDelete), {
                            IsDeleted: true,
                            DeletedAt: serverTimestamp(),
                            Status: "Deactivated"
                        });
                    }
                    modal.classList.add("hidden");
                    userToDelete = null;
                } catch (err) {
                    console.error("Error updating user:", err);
                }
            });
        }

        function openDeleteUserModal() {
            const modal = document.getElementById("deleteUserModal");
            const title = document.getElementById("userActionTitle");
            const body = document.getElementById("userActionBody");
            const btnConfirm = document.getElementById("btnConfirmDeleteUser");

            if (pendingAction === "reactivate") {
                title.textContent = "Reactivate User?";
                body.textContent = "Are you sure you want to reactivate this user? They will regain access to their account.";
                btnConfirm.className = "px-4 py-2 rounded-lg bg-emerald-500 text-white hover:bg-emerald-600";
            } else {
                title.textContent = "Deactivate User?";
                body.textContent = "Are you sure you want to deactivate this user? Their account will be locked, but their data and job history will be preserved.";
                btnConfirm.className = "px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600";
            }

            modal.classList.remove("hidden");
        }
    </script>

</asp:Content>

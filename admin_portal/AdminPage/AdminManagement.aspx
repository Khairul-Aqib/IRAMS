<%@ Page Title="Admin Management" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="AdminManagement.aspx.cs" Inherits="AdminPage.AdminManagement" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Admin Management
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Page content (hidden until role verified) -->
    <div id="pageContent" class="hidden">

        <div class="flex items-center justify-between mb-6">
            <h1 class="text-3xl font-bold text-yellow-400">Admin Management</h1>
            <button type="button" id="btnOpenCreateModal"
                    class="bg-yellow-500 hover:bg-yellow-600 text-black font-semibold px-5 py-2 rounded-lg">
                + Create New Admin
            </button>
        </div>

        <!-- Admin Table -->
        <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">
            <div class="overflow-x-auto">
                <table class="min-w-full text-sm">
                    <thead>
                        <tr class="bg-[#262626] text-gray-300">
                            <th class="py-3 px-4 text-left">Name</th>
                            <th class="py-3 px-4 text-left">Email</th>
                            <th class="py-3 px-4 text-left">Role</th>
                            <th class="py-3 px-4 text-left">Status</th>
                            <th class="py-3 px-4 text-left">Created By</th>
                            <th class="py-3 px-4 text-left">Created When</th>
                            <th class="py-3 px-4 text-left">Action</th>
                        </tr>
                    </thead>
                    <tbody id="adminsTableBody">
                        <tr>
                            <td colspan="7" class="py-4 px-4 text-center text-gray-400">Loading admins...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Deactivate Confirmation Modal -->
    <div id="deactivateModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
            <h3 class="text-lg font-semibold mb-2">Deactivate Admin?</h3>
            <p class="text-sm text-gray-600 mb-6">
                Are you sure you want to deactivate this admin account? They will no longer be able to log in.
            </p>
            <div class="flex justify-end gap-3">
                <button type="button" id="btnCancelDeactivate"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300">
                    Cancel
                </button>
                <button type="button" id="btnConfirmDeactivate"
                        class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600">
                    Deactivate
                </button>
            </div>
        </div>
    </div>

    <!-- Create Admin Modal -->
    <div id="createAdminModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-[#1f1f1f] rounded-xl p-6 w-full max-w-lg border border-[#333]">
            <h3 class="text-xl font-semibold mb-5 text-yellow-400">Create New Admin</h3>

            <div class="space-y-4">
                <div>
                    <label class="block text-sm text-gray-300 mb-1">Full Name</label>
                    <input type="text" id="inputName"
                           class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm text-white" />
                </div>
                <div>
                    <label class="block text-sm text-gray-300 mb-1">Email</label>
                    <input type="email" id="inputEmail"
                           class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm text-white" />
                </div>
                <div>
                    <label class="block text-sm text-gray-300 mb-1">Password</label>
                    <input type="password" id="inputPassword"
                           class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm text-white" />
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm text-gray-300 mb-1">IC Number</label>
                        <input type="text" id="inputIC"
                               class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm text-white" />
                    </div>
                    <div>
                        <label class="block text-sm text-gray-300 mb-1">Phone</label>
                        <input type="text" id="inputPhone"
                               class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm text-white" />
                    </div>
                </div>
                <div>
                    <label class="block text-sm text-gray-300 mb-1">Role</label>
                    <select id="inputRole"
                            class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm text-white">
                        <option value="Admin">Admin</option>
                        <option value="Manager">Manager</option>
                    </select>
                </div>
            </div>

            <!-- Error message -->
            <p id="createError" class="text-red-400 text-sm mt-3 hidden"></p>

            <div class="flex justify-end gap-3 mt-6">
                <button type="button" id="btnCancelCreate"
                        class="px-4 py-2 rounded-lg bg-gray-600 text-white hover:bg-gray-500">
                    Cancel
                </button>
                <button type="button" id="btnSubmitCreate"
                        class="px-5 py-2 rounded-lg bg-yellow-500 text-black font-semibold hover:bg-yellow-600 flex items-center gap-2">
                    <svg id="createSpinner" class="hidden animate-spin h-4 w-4 text-black" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                    </svg>
                    Create Admin
                </button>
            </div>
        </div>
    </div>

    <script type="module">
        import {
            collection,
            query,
            where,
            or,
            getDocs,
            onSnapshot,
            updateDoc,
            doc
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        import { getAuth } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
        import { getFunctions, httpsCallable } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-functions.js";

        let adminToDeactivate = null; // doc id

        document.addEventListener("firebase-auth-ready", async () => {
            // ── 1. ROLE GUARD ──────────────────────────────────────────
            const email = window.__adminEmail;
            let isManager = false;

            if (email) {
                try {
                    const q = query(collection(db, "Admins"), where("AdminEmail", "==", email));
                    const snap = await getDocs(q);
                    if (!snap.empty && snap.docs[0].data().Role === "Manager") {
                        isManager = true;
                    }
                } catch (e) {
                    console.error("Role check failed:", e);
                }
            }

            if (!isManager) {
                alert("Access denied. Only Managers can access Admin Management.");
                window.location.href = "Dashboard.aspx";
                return;
            }

            // Role verified — show the page
            document.getElementById("pageContent").classList.remove("hidden");

            // ── 2. LOAD ADMINS TABLE ───────────────────────────────────
            const currentUid = getAuth().currentUser?.uid;
            loadAdmins(currentUid);

            // ── 3. WIRE UP MODALS ──────────────────────────────────────
            setupDeactivateModal();
            setupCreateModal();
        });

        // ================================================================
        // ADMIN TABLE
        // ================================================================
        function loadAdmins(currentUid) {
            const tbody = document.getElementById("adminsTableBody");

            // Show all Admins + the current Manager (hide other Managers)
            const adminsQuery = query(
                collection(db, "Admins"),
                or(
                    where("Role", "==", "Admin"),
                    where("uid", "==", currentUid || "")
                )
            );
            onSnapshot(adminsQuery, (snap) => {
                tbody.innerHTML = "";

                if (snap.empty) {
                    tbody.innerHTML = "<tr><td colspan='7' class='py-4 px-4 text-center text-gray-400'>No admin accounts found.</td></tr>";
                    return;
                }

                snap.forEach(docSnap => {
                    const a = docSnap.data();
                    const tr = document.createElement("tr");
                    tr.className = "border-b border-[#333] hover:bg-[#262626]";

                    const status = a.AdminStatus || "Active";
                    const isActive = status === "Active";
                    const statusColor = isActive ? "bg-emerald-500" : "bg-red-500";

                    // Format created date
                    let createdWhen = "-";
                    if (a.CreatedWhen) {
                        const d = a.CreatedWhen.toDate ? a.CreatedWhen.toDate() : new Date(a.CreatedWhen.seconds * 1000);
                        createdWhen = d.toLocaleDateString("en-MY", {
                            year: "numeric", month: "short", day: "numeric",
                            hour: "2-digit", minute: "2-digit"
                        });
                    }

                    tr.innerHTML = `
                        <td class="py-3 px-4">${a.AdminName || "-"}</td>
                        <td class="py-3 px-4">${a.AdminEmail || "-"}</td>
                        <td class="py-3 px-4">
                            <span class="px-3 py-1 rounded text-xs whitespace-nowrap ${a.Role === 'Manager' ? 'bg-purple-600' : 'bg-blue-600'} text-white">
                                ${a.Role || "-"}
                            </span>
                        </td>
                        <td class="py-3 px-4">
                            <span class="px-3 py-1 rounded-full text-xs font-semibold text-white ${statusColor}">
                                ${status}
                            </span>
                        </td>
                        <td class="py-3 px-4">${a.AccountCreatedByWhichManager || "-"}</td>
                        <td class="py-3 px-4">${createdWhen}</td>
                        <td class="py-3 px-4">
                            <div class="flex gap-3 text-xs">
                                <a href="AdminEdit.aspx?uid=${a.uid || docSnap.id}" class="text-blue-400 hover:underline">Edit</a>
                                ${isActive
                                    ? `<button type="button" class="text-red-400 hover:underline deactivate-btn" data-id="${docSnap.id}">Deactivate</button>`
                                    : `<span class="text-gray-500">Deactivated</span>`
                                }
                            </div>
                        </td>
                    `;
                    tbody.appendChild(tr);
                });

                // Attach deactivate button listeners
                document.querySelectorAll(".deactivate-btn").forEach(btn => {
                    btn.addEventListener("click", () => {
                        adminToDeactivate = btn.dataset.id;
                        document.getElementById("deactivateModal").classList.remove("hidden");
                    });
                });
            }, (err) => {
                console.error("Error loading admins:", err);
                tbody.innerHTML = "<tr><td colspan='7' class='py-4 px-4 text-center text-red-400'>Error loading admins.</td></tr>";
            });
        }

        // ================================================================
        // DEACTIVATE MODAL
        // ================================================================
        function setupDeactivateModal() {
            const modal = document.getElementById("deactivateModal");

            document.getElementById("btnCancelDeactivate").addEventListener("click", () => {
                adminToDeactivate = null;
                modal.classList.add("hidden");
            });

            document.getElementById("btnConfirmDeactivate").addEventListener("click", async () => {
                if (!adminToDeactivate) return;
                try {
                    await updateDoc(doc(db, "Admins", adminToDeactivate), {
                        AdminStatus: "Deactivated"
                    });
                    modal.classList.add("hidden");
                    adminToDeactivate = null;
                } catch (err) {
                    console.error("Deactivation error:", err);
                    alert("Failed to deactivate admin. See console for details.");
                }
            });
        }

        // ================================================================
        // CREATE ADMIN MODAL
        // ================================================================
        function setupCreateModal() {
            const modal = document.getElementById("createAdminModal");
            const spinner = document.getElementById("createSpinner");
            const errorEl = document.getElementById("createError");
            const submitBtn = document.getElementById("btnSubmitCreate");

            document.getElementById("btnOpenCreateModal").addEventListener("click", () => {
                clearCreateForm();
                modal.classList.remove("hidden");
            });

            document.getElementById("btnCancelCreate").addEventListener("click", () => {
                modal.classList.add("hidden");
            });

            submitBtn.addEventListener("click", async () => {
                errorEl.classList.add("hidden");

                const name     = document.getElementById("inputName").value.trim();
                const email    = document.getElementById("inputEmail").value.trim();
                const password = document.getElementById("inputPassword").value.trim();
                const ic       = document.getElementById("inputIC").value.trim();
                const phone    = document.getElementById("inputPhone").value.trim();
                const role     = document.getElementById("inputRole").value;

                // Basic validation
                if (!name || !email || !password || !ic || !phone) {
                    errorEl.textContent = "All fields are required.";
                    errorEl.classList.remove("hidden");
                    return;
                }

                // Show spinner, disable button
                spinner.classList.remove("hidden");
                submitBtn.disabled = true;

                try {
                    const functions = getFunctions(undefined, "asia-southeast1");
                    const createAdminAccount = httpsCallable(functions, "createAdminAccount");

                    await createAdminAccount({
                        name,
                        email,
                        password,
                        ic,
                        phone,
                        role
                    });

                    // Success — close modal; table refreshes via onSnapshot
                    modal.classList.add("hidden");
                    clearCreateForm();
                } catch (err) {
                    console.error("Create admin error:", err);
                    errorEl.textContent = err.message || "Failed to create admin account.";
                    errorEl.classList.remove("hidden");
                } finally {
                    spinner.classList.add("hidden");
                    submitBtn.disabled = false;
                }
            });
        }

        function clearCreateForm() {
            document.getElementById("inputName").value = "";
            document.getElementById("inputEmail").value = "";
            document.getElementById("inputPassword").value = "";
            document.getElementById("inputIC").value = "";
            document.getElementById("inputPhone").value = "";
            document.getElementById("inputRole").value = "Admin";
            document.getElementById("createError").classList.add("hidden");
        }
    </script>

</asp:Content>

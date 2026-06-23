<%@ Page Title="Contractors Management" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="Contractors.aspx.cs" Inherits="AdminPage.Contractors" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Contractors Management
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-8 text-yellow-400">Contractors Management</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">

        <!-- header row -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Contractors List</h2>

            <div class="flex items-center gap-3">
                <!-- Sort -->
                <select id="sortContractors"
                        class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm">
                    <option value="name-asc">Name (A–Z)</option>
                    <option value="name-desc">Name (Z–A)</option>
                    <option value="id-asc">Contractor ID (C001→)</option>
                    <option value="status-active">Account Status (Active first)</option>
                    <option value="verify-pending">Verification (Verified first)</option>
                    <option value="jobs-desc">Total Jobs (High→Low)</option>
                    <option value="lastlogin-desc">Last Login (Newest)</option>
                </select>

                <!-- Search -->
                <div class="relative">
                    <input id="contractorSearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-72"
                           placeholder="Search (Name, Email, or ID)" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>
            </div>
        </div>

        <!-- table -->
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Contractor ID</th>
                        <th class="py-3 px-4 text-left">Full Name</th>
                        <th class="py-3 px-4 text-left">Email Address</th>
                        <th class="py-3 px-4 text-left">Phone Number</th>
                        <th class="py-3 px-4 text-left">Service Types</th>
                        <th class="py-3 px-4 text-left">Account Status</th>
                        <th class="py-3 px-4 text-left">Verification</th>
                        <th class="py-3 px-4 text-left">Total Jobs</th>
                        <th class="py-3 px-4 text-left">Last Login</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="contractorsTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- DELETE MODAL -->
    <div id="deleteContractorModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
            <h3 class="text-lg font-semibold mb-2">Deactivate Contractor?</h3>
            <p class="text-sm text-gray-600 mb-6">
                Are you sure you want to Deactivate and archive this contractor? Their account will be locked, but their job history will be preserved for accounting.
            </p>
            <div class="flex justify-end gap-3">
                <button type="button"
                        id="btnCancelDeleteContractor"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300 cursor-pointer">
                    Cancel
                </button>
                <button type="button"
                        id="btnConfirmDeleteContractor"
                        class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 cursor-pointer">
                    Confirm
                </button>
            </div>
        </div>
    </div>

    <script type="module">
        import {
            collection,
            getDocs,
            onSnapshot,
            updateDoc,
            doc
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        function formatDateTime(value) {
            if (!value) return "";
            if (typeof value.toDate === "function") {
                return formatDateToString(value.toDate());
            }
            const d = new Date(value);
            if (!isNaN(d.getTime())) return formatDateToString(d);
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

        function formatContractorId(id) {
            if (!id) return "";
            if (id.length > 8) {
                const display = id.slice(0, 4) + "..." + id.slice(-4);
                return `<span title="${id}">${display}</span>`;
            }
            return `<span title="${id}">${id}</span>`;
        }

        let contractors = [];
        let contractorToDelete = null;
        let currentSearch = "";
        let currentSort = "name-asc";

        document.addEventListener("firebase-auth-ready", () => {
            loadContractors();
            setupSearch();
            setupSort();
            setupDeleteModal();
        });

        function loadContractors() {
            const tbody = document.getElementById("contractorsTableBody");
            tbody.innerHTML = "<tr><td colspan='10' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            onSnapshot(collection(db, "Contractor"), (snap) => {
                contractors = [];
                snap.forEach(docSnap => {
                    contractors.push({ id: docSnap.id, ...docSnap.data() });
                });
                applyContractorFiltersAndSort();
            }, (err) => {
                console.error("Error loading contractors:", err);
                tbody.innerHTML = "<tr><td colspan='10' class='py-4 px-4 text-center text-red-400'>Failed to load contractors.</td></tr>";
            });
        }

        function applyContractorFiltersAndSort() {
            let list = contractors.slice();

            if (currentSearch) {
                list = list.filter(c =>
                    (c.FullName || "").toLowerCase().includes(currentSearch) ||
                    (c.Email || "").toLowerCase().includes(currentSearch) ||
                    (c.ContractorID || "").toLowerCase().includes(currentSearch)
                );
            }

            list = sortContractors(list);
            renderContractors(list);
        }

        function sortContractors(list) {
            const getName = c => (c.FullName || "").toLowerCase();
            const getIdNum = c => {
                const id = c.ContractorID || "";
                const num = parseInt(id.substring(1));
                return isNaN(num) ? 0 : num;
            };
            const getJobs = c => parseInt(c.TotalJobs || "0") || 0;
            const getLastLogin = c => {
                const v = c.LastLogin;
                if (v && typeof v.toDate === "function") return v.toDate().getTime();
                const d = new Date(v || "1970-01-01");
                return d.getTime();
            };
            const getAcc = c => (c.AccountStatus || "").toLowerCase();
            const getVerify = c => (c.VerificationStatus || "").toLowerCase();

            switch (currentSort) {
                case "name-desc":
                    return list.sort((a, b) => getName(b).localeCompare(getName(a)));
                case "id-asc":
                    return list.sort((a, b) => getIdNum(a) - getIdNum(b));
                case "jobs-desc":
                    return list.sort((a, b) => getJobs(b) - getJobs(a));
                case "lastlogin-desc":
                    return list.sort((a, b) => getLastLogin(b) - getLastLogin(a));
                case "status-active":
                    return list.sort((a, b) => {
                        const av = getAcc(a) === "active" ? 0 : 1;
                        const bv = getAcc(b) === "active" ? 0 : 1;
                        if (av !== bv) return av - bv;
                        return getName(a).localeCompare(getName(b));
                    });
                case "verify-pending":
                    return list.sort((a, b) => {
                        const av = getVerify(a) === "verified" ? 0 : 1;
                        const bv = getVerify(b) === "verified" ? 0 : 1;
                        if (av !== bv) return av - bv;
                        return getName(a).localeCompare(getName(b));
                    });
                case "name-asc":
                default:
                    return list.sort((a, b) => getName(a).localeCompare(getName(b)));
            }
        }

        function renderContractors(list) {
            const tbody = document.getElementById("contractorsTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='10' class='py-4 px-4 text-center text-gray-400'>No contractors found.</td></tr>";
                return;
            }

            for (const c of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                const isDeleted = c.IsDeleted === true;
                const acc = isDeleted ? "Archived" : (c.AccountStatus || "").toString();
                const accLower = acc.toLowerCase();
                let accColor = "bg-red-500";
                if (isDeleted) {
                    accColor = "bg-gray-500";
                } else if (accLower === "active") {
                    accColor = "bg-emerald-500";
                } else if (accLower === "deactivated") {
                    accColor = "bg-gray-500";
                }

                const verRaw = (c.VerificationStatus || "Pending").toString().toLowerCase();
                let verColor = "bg-yellow-500";
                let verLabel = "Pending";
                if (verRaw === "verified" || verRaw === "approved") {
                    verColor = "bg-emerald-500";
                    verLabel = "Verified";
                } else if (verRaw === "rejected") {
                    verColor = "bg-red-500";
                    verLabel = "Rejected";
                } else if (verRaw === "under_review") {
                    verColor = "bg-yellow-500";
                    verLabel = "Pending";
                }

                const svcList = Array.isArray(c.ServiceTypes)
                    ? c.ServiceTypes.join(", ")
                    : (c.ServiceTypes || "");

                tr.innerHTML = `
                    <td class="py-3 px-4">${formatContractorId(c.ConID)}</td>
                    <td class="py-3 px-4">${c.FullName || ""}</td>
                    <td class="py-3 px-4">${c.Email || ""}</td>
                    <td class="py-3 px-4">${c.PhoneNumber || ""}</td>
                    <td class="py-3 px-4">${svcList}</td>
                    <td class="py-3 px-4">
                        <span class="inline-block px-3 py-1 rounded-full text-xs font-semibold text-white ${accColor}">
                            ${acc || "-"}
                        </span>
                    </td>
                    <td class="py-3 px-4">
                        <span class="inline-block px-3 py-1 rounded-full text-xs font-semibold text-white ${verColor}">
                            ${verLabel}
                        </span>
                    </td>
                    <td class="py-3 px-4">${c.TotalJobs || 0}</td>
                    <td class="py-3 px-4">${formatDateTime(c.LastLogin)}</td>
                    <td class="py-3 px-4">
                        <div class="flex gap-2 text-xs">
                            <a href="ContractorProfile.aspx?id=${c.id}" class="text-blue-400 hover:underline">View</a>
                            <button type="button"
                                class="text-red-400 hover:underline delete-contractor-btn cursor-pointer"
                                data-id="${c.id}"
                                ${isDeleted ? 'disabled style="opacity:0.4;cursor:not-allowed;"' : ''}>
                                ${isDeleted ? 'Archived' : 'Deactivate'}
                            </button>
                        </div>
                    </td>
                `;
                tbody.appendChild(tr);
            }

            document.querySelectorAll(".delete-contractor-btn").forEach(btn => {
                btn.addEventListener("click", () => {
                    contractorToDelete = btn.dataset.id;
                    openDeleteContractorModal();
                });
            });
        }

        function setupSearch() {
            const input = document.getElementById("contractorSearch");
            input.addEventListener("input", () => {
                currentSearch = input.value.toLowerCase();
                applyContractorFiltersAndSort();
            });
        }

        function setupSort() {
            const select = document.getElementById("sortContractors");
            select.addEventListener("change", () => {
                currentSort = select.value;
                applyContractorFiltersAndSort();
            });
        }

        function setupDeleteModal() {
            const modal = document.getElementById("deleteContractorModal");
            const btnCancel = document.getElementById("btnCancelDeleteContractor");
            const btnConfirm = document.getElementById("btnConfirmDeleteContractor");

            btnCancel.addEventListener("click", () => {
                contractorToDelete = null;
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                if (!contractorToDelete) return;
                try {
                    await updateDoc(doc(db, "Contractor", contractorToDelete), {
                        IsDeleted: true,
                        AccountStatus: "Deactivated"
                    });
                    modal.classList.add("hidden");
                    contractorToDelete = null;
                } catch (err) {
                    console.error("Error deactivating contractor:", err);
                }
            });
        }

        function openDeleteContractorModal() {
            document.getElementById("deleteContractorModal").classList.remove("hidden");
        }
    </script>

</asp:Content>

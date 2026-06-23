<%@ Page Title="Services Management" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="Services.aspx.cs" Inherits="AdminPage.Services" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Services Management
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

    <!-- PAGE TITLE -->
    <h1 class="text-3xl font-bold mb-8 text-yellow-400">Services Management</h1>

    <!-- SUMMARY CARDS -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">

        <!-- Total Services -->
        <div class="bg-[#1f1f1f] rounded-xl p-5 border border-[#333]">
            <p class="text-sm text-gray-400 mb-1">Total Services</p>
            <p class="text-4xl font-bold text-yellow-400" id="totalServicesCount">0</p>
        </div>

        <!-- Active Services -->
        <div class="bg-[#1f1f1f] rounded-xl p-5 border border-[#333]">
            <p class="text-sm text-gray-400 mb-1">Active Services</p>
            <p class="text-4xl font-bold text-green-400" id="activeServicesCount">0</p>
        </div>

        <!-- Inactive Services -->
        <div class="bg-[#1f1f1f] rounded-xl p-5 border border-[#333]">
            <p class="text-sm text-gray-400 mb-1">Inactive Services</p>
            <p class="text-4xl font-bold text-red-400" id="inactiveServicesCount">0</p>
        </div>

    </div>

    <!-- SERVICES TABLE CARD -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">

        <!-- Header row -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">

            <!-- LEFT SIDE: Sort + Search -->
            <div class="flex items-center gap-3">

                <!-- Sort By -->
                <div>
                    <select id="sortServices"
                            class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm">
                        <option value="name-asc">Service Name (A–Z)</option>
                        <option value="name-desc">Service Name (Z–A)</option>
                        <option value="price-asc">Base Price (Low–High)</option>
                        <option value="price-desc">Base Price (High–Low)</option>
                        <option value="status-active">Status (Active first)</option>
                        <option value="id-asc">Service ID (S001 → S999)</option>
                    </select>
                </div>

                <!-- Search -->
                <div class="relative">
                    <input id="serviceSearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-80"
                           placeholder="Search by name or description" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>

            </div>

            <!-- RIGHT SIDE: Add Service Button -->
            <asp:HyperLink ID="lnkAddService" runat="server"
                NavigateUrl="~/ServiceAdd.aspx"
                CssClass="bg-blue-500 hover:bg-blue-600 text-white text-sm font-semibold px-4 py-2 rounded-lg">
                Add New Service
            </asp:HyperLink>

        </div>

        <!-- SERVICES TABLE -->
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Service ID</th>
                        <th class="py-3 px-4 text-left">Service Name</th>
                        <th class="py-3 px-4 text-left">Base Price (RM)</th>
                        <th class="py-3 px-4 text-left">Status</th>
                        <th class="py-3 px-4 text-left">Description</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="servicesTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- ACTION CONFIRM MODAL (text adapts at open time) -->
    <div id="deleteModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
            <h3 id="serviceActionTitle" class="text-lg font-semibold mb-2">Deactivate Service?</h3>
            <p id="serviceActionBody" class="text-sm text-gray-600 mb-6">
                This service will be marked Inactive and hidden from users until reactivated.
            </p>

            <div class="flex justify-end gap-3">
                <button type="button"
                        id="btnCancelDelete"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300">
                    Cancel
                </button>
                <button type="button"
                        id="btnConfirmDelete"
                        class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600">
                    Confirm
                </button>
            </div>
        </div>
    </div>

    <!-- the JS services logic -->
    <script type="module">
        import {
            collection,
            getDocs,
            onSnapshot,
            updateDoc,
            doc
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        let services = [];
        let serviceToToggle = null;       // Firestore doc id
        let pendingAction = "deactivate"; // or "reactivate"

        let currentSearch = "";
        let currentSort = "id-asc";

        document.addEventListener("firebase-auth-ready", () => {
            loadServices();
            setupSearch();
            setupSort();
            setupDeleteModal();
        });

        function loadServices() {
            const tbody = document.getElementById("servicesTableBody");
            tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            onSnapshot(collection(db, "Services"), (snap) => {
                services = [];
                snap.forEach(docSnap => {
                    services.push({ id: docSnap.id, ...docSnap.data() });
                });
                applyFiltersAndSort();
                updateSummaryCards(services);
            }, (err) => {
                console.error("Error loading services:", err);
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-red-400'>Failed to load services.</td></tr>";
            });
        }

        function applyFiltersAndSort() {
            // start from full list
            let list = services.slice();

            // first filter by search text
            if (currentSearch) {
                list = list.filter(s =>
                    (s.ServiceName || "").toLowerCase().includes(currentSearch) ||
                    (s.Description || "").toLowerCase().includes(currentSearch)
                );
            }

            // then sort
            list = sortServices(list);

            // and then render
            renderServices(list);
        }

        function sortServices(list) {
            const getPrice = s => parseFloat(s.BasePrice || s.basePrice || "0") || 0;
            const getName = s => (s.ServiceName || "").toLowerCase();
            const getStatus = s => (s.Status || s.status || "").toLowerCase();
            const getIdNum = s => {
                const id = s.ServiceID || "";
                const num = parseInt(id.substring(1));
                return isNaN(num) ? 0 : num;
            };

            switch (currentSort) {
                case "name-desc":
                    return list.sort((a, b) => getName(b).localeCompare(getName(a)));
                case "price-asc":
                    return list.sort((a, b) => getPrice(a) - getPrice(b));
                case "price-desc":
                    return list.sort((a, b) => getPrice(b) - getPrice(a));
                case "status-active":
                    // Active (0) before others (1)
                    return list.sort((a, b) => {
                        const aVal = getStatus(a) === "active" ? 0 : 1;
                        const bVal = getStatus(b) === "active" ? 0 : 1;
                        if (aVal !== bVal) return aVal - bVal;
                        return getName(a).localeCompare(getName(b));
                    });
                case "id-asc":
                    return list.sort((a, b) => getIdNum(a) - getIdNum(b));
                case "name-asc":
                default:
                    return list.sort((a, b) => getName(a).localeCompare(getName(b)));
            }
        }

        function renderServices(list) {
            const tbody = document.getElementById("servicesTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>No services found.</td></tr>";
                return;
            }

            for (const svc of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                const status = (svc.Status || svc.status || "").toString();
                const isActive = status.toLowerCase() === "active";

                const statusClass = isActive ? "bg-emerald-500" : "bg-red-500";

                const actionLabel = isActive ? "Deactivate" : "Reactivate";
                const actionType  = isActive ? "deactivate" : "reactivate";
                const actionColor = isActive ? "text-red-400" : "text-emerald-400";

                tr.innerHTML = `
                    <td class="py-3 px-4">${svc.ServiceID || ""}</td>
                    <td class="py-3 px-4">${svc.ServiceName || ""}</td>
                    <td class="py-3 px-4">RM ${svc.BasePrice || "0"}</td>

                    <td class="py-3 px-4">
                        <span class="inline-block px-3 py-1 rounded-full text-xs font-semibold text-white ${statusClass}">
                            ${status || "-"}
                        </span>
                    </td>

                    <td class="py-3 px-4">${svc.Description || ""}</td>
                    <td class="py-3 px-4">
                        <a href="ServiceEdit.aspx?id=${svc.id}" class="text-blue-400 hover:underline mr-3">Edit</a>
                        <button type="button"
                            class="${actionColor} hover:underline service-action-btn"
                            data-id="${svc.id}"
                            data-action="${actionType}">
                            ${actionLabel}
                        </button>
                    </td>
                `;
                tbody.appendChild(tr);
            }

            document.querySelectorAll(".service-action-btn").forEach(btn => {
                btn.addEventListener("click", () => {
                    serviceToToggle = btn.dataset.id;
                    pendingAction = btn.dataset.action;
                    openDeleteModal();
                });
            });
        }

        function updateSummaryCards(list) {
            const total = list.length;
            const active = list.filter(s => (s.Status || s.status || "").toLowerCase() === "active").length;
            const inactive = total - active;

            document.getElementById("totalServicesCount").textContent = total;
            document.getElementById("activeServicesCount").textContent = active;
            document.getElementById("inactiveServicesCount").textContent = inactive;
        }

        function setupSearch() {
            const input = document.getElementById("serviceSearch");
            input.addEventListener("input", () => {
                currentSearch = input.value.toLowerCase();
                applyFiltersAndSort();
            });
        }

        function setupSort() {
            const select = document.getElementById("sortServices");
            select.addEventListener("change", () => {
                currentSort = select.value;
                applyFiltersAndSort();
            });
        }

        // Modal serves both deactivate and reactivate flows — text and confirm
        // colour are swapped at open time based on pendingAction.
        function setupDeleteModal() {
            const modal = document.getElementById("deleteModal");
            const btnCancel = document.getElementById("btnCancelDelete");
            const btnConfirm = document.getElementById("btnConfirmDelete");

            btnCancel.addEventListener("click", () => {
                serviceToToggle = null;
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                if (!serviceToToggle) return;

                try {
                    const newStatus = pendingAction === "reactivate" ? "Active" : "Inactive";
                    const update = { Status: newStatus };
                    // Reactivating also clears any legacy soft-delete flag so the
                    // service comes fully back online.
                    if (pendingAction === "reactivate") update.IsDeleted = false;

                    await updateDoc(doc(db, "Services", serviceToToggle), update);
                    modal.classList.add("hidden");
                    serviceToToggle = null;
                } catch (err) {
                    console.error("Error updating service status:", err);
                    alert("Failed to update service: " + (err && err.message ? err.message : err));
                }
            });
        }

        function openDeleteModal() {
            const modal = document.getElementById("deleteModal");
            const title = document.getElementById("serviceActionTitle");
            const body = document.getElementById("serviceActionBody");
            const btnConfirm = document.getElementById("btnConfirmDelete");

            if (pendingAction === "reactivate") {
                title.textContent = "Reactivate Service?";
                body.textContent = "This service will be marked Active and made available to users again.";
                btnConfirm.className = "px-4 py-2 rounded-lg bg-emerald-500 text-white hover:bg-emerald-600";
            } else {
                title.textContent = "Deactivate Service?";
                body.textContent = "This service will be marked Inactive and hidden from users until reactivated.";
                btnConfirm.className = "px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600";
            }

            modal.classList.remove("hidden");
        }
    </script>

</asp:Content>

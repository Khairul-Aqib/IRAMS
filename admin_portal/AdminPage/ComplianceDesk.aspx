<%@ Page Title="Compliance Desk" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="ComplianceDesk.aspx.cs" Inherits="AdminPage.ComplianceDesk" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Compliance Desk
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-8 text-yellow-400">Compliance Desk</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">

        <!-- header row -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Pending Approvals</h2>

            <div class="flex items-center gap-3">
                <!-- Search -->
                <div class="relative">
                    <input id="approvalSearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-72"
                           placeholder="Search by Name or Email" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>
            </div>
        </div>

        <!-- table -->
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Full Name</th>
                        <th class="py-3 px-4 text-left">Email Address</th>
                        <th class="py-3 px-4 text-left">Phone Number</th>
                        <th class="py-3 px-4 text-left">Submitted</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="approvalsTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- Compliance History Section -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6 mt-8">

        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Compliance History</h2>

            <div class="flex items-center gap-3">
                <div class="relative">
                    <input id="historySearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-72"
                           placeholder="Search by Name or Contractor ID" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>
            </div>
        </div>

        <div style="max-height: 400px; overflow-y: auto; display: block;">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Date Processed</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Contractor ID</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Name</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Action</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Admin</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Details</th>
                    </tr>
                </thead>
                <tbody id="complianceHistoryBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- Snapshot Modal -->
    <div id="snapshotModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
            <div class="flex items-center justify-between mb-6">
                <h3 class="text-lg font-semibold text-yellow-400">Compliance Record Snapshot</h3>
                <button type="button" id="btnCloseSnapshot"
                        class="text-gray-400 hover:text-white text-2xl leading-none cursor-pointer">&times;</button>
            </div>
            <div id="snapshotContent"></div>
        </div>
    </div>

    <script type="module">
        import {
            collection,
            query,
            where,
            getDocs,
            onSnapshot,
            orderBy,
            limit
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        let pending = [];
        let currentSearch = "";

        let complianceLogs = [];
        let historySearchTerm = "";

        document.addEventListener("firebase-auth-ready", () => {
            loadPending();
            setupSearch();
            loadComplianceHistory();
            setupHistorySearch();
        });

        function loadPending() {
            const tbody = document.getElementById("approvalsTableBody");
            tbody.innerHTML = "<tr><td colspan='5' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            const q = query(
                collection(db, "Contractor"),
                where("VerificationStatus", "==", "under_review")
            );

            onSnapshot(q, (snap) => {
                pending = [];
                snap.forEach(docSnap => {
                    pending.push({ id: docSnap.id, ...docSnap.data() });
                });

                // update sidebar badge
                const badge = document.getElementById("complianceBadge");
                if (badge) {
                    badge.textContent = pending.length;
                    badge.classList.toggle("hidden", pending.length === 0);
                }

                applyFilter();
            }, (err) => {
                console.error("Error loading pending approvals:", err);
                tbody.innerHTML = "<tr><td colspan='5' class='py-4 px-4 text-center text-red-400'>Failed to load pending approvals.</td></tr>";
            });
        }

        function applyFilter() {
            let list = pending.slice();

            if (currentSearch) {
                list = list.filter(c =>
                    (c.FullName || "").toLowerCase().includes(currentSearch) ||
                    (c.Email || "").toLowerCase().includes(currentSearch)
                );
            }

            list.sort((a, b) => (a.FullName || "").localeCompare(b.FullName || ""));
            renderTable(list);
        }

        function renderTable(list) {
            const tbody = document.getElementById("approvalsTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='5' class='py-4 px-4 text-center text-gray-400'>No pending approvals.</td></tr>";
                return;
            }

            for (const c of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                let rawDate = c.LastSubmittedAt || c.lastSubmittedAt || c.RegistrationDate || c.registrationDate;
                let submitDate = rawDate ? (typeof rawDate.toDate === 'function' ? rawDate.toDate() : new Date(rawDate)) : null;
                let submitted = submitDate ? submitDate.toLocaleString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'N/A';

                tr.innerHTML = `
                    <td class="py-3 px-4">${c.FullName || ""}</td>
                    <td class="py-3 px-4">${c.Email || ""}</td>
                    <td class="py-3 px-4">${c.PhoneNumber || ""}</td>
                    <td class="py-3 px-4 text-gray-400">${submitted}</td>
                    <td class="py-3 px-4">
                        <a href="ContractorProfile.aspx?id=${c.id}"
                           class="inline-flex items-center gap-1 px-4 py-1.5 rounded-lg bg-yellow-500 text-black text-xs font-semibold hover:bg-yellow-400 transition">
                            Review
                        </a>
                    </td>
                `;
                tbody.appendChild(tr);
            }
        }

        function setupSearch() {
            const input = document.getElementById("approvalSearch");
            input.addEventListener("input", () => {
                currentSearch = input.value.toLowerCase();
                applyFilter();
            });
        }

        // ══════════════════════════════════════════════════════════
        // ── Compliance History (Audit Log) ───────────────────────
        // ══════════════════════════════════════════════════════════

        function formatDateTime(value) {
            if (!value) return "";
            const d = typeof value.toDate === "function" ? value.toDate() : new Date(value);
            if (isNaN(d.getTime())) return "";
            const day   = String(d.getDate()).padStart(2, "0");
            const month = String(d.getMonth() + 1).padStart(2, "0");
            const year  = d.getFullYear();
            const hours = String(d.getHours()).padStart(2, "0");
            const mins  = String(d.getMinutes()).padStart(2, "0");
            return `${day}/${month}/${year} ${hours}:${mins}`;
        }

        function formatContractorId(id) {
            if (!id) return "";
            if (id.length > 8) {
                const display = id.slice(0, 4) + "..." + id.slice(-4);
                return `<span title="${id}">${display}</span>`;
            }
            return `<span title="${id}">${id}</span>`;
        }

        function loadComplianceHistory() {
            const tbody = document.getElementById("complianceHistoryBody");
            tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            const historyQuery = query(
                collection(db, "ComplianceLogs"),
                orderBy("Timestamp", "desc"),
                limit(50)
            );

            onSnapshot(historyQuery, (snap) => {
                complianceLogs = [];

                snap.forEach(docSnap => {
                    const d = { id: docSnap.id, ...docSnap.data() };
                    d._timestamp = d.Timestamp || d.timestamp || null;
                    d._contractorId = d.ContractorID || d.contractorId || "";
                    d._name = d.ContractorName || d.contractorName || "-";
                    d._action = d.Action || d.action || "-";
                    d._admin = d.Admin || d.admin || "System Admin";
                    complianceLogs.push(d);
                });

                applyHistoryFilter();
            }, (err) => {
                console.error("Error loading compliance history:", err);
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-red-400'>Failed to load compliance history.</td></tr>";
            });
        }

        function applyHistoryFilter() {
            let list = complianceLogs.slice();

            if (historySearchTerm) {
                list = list.filter(l =>
                    (l._name || "").toLowerCase().includes(historySearchTerm) ||
                    (l._contractorId || "").toLowerCase().includes(historySearchTerm)
                );
            }

            // Sort newest first
            list.sort((a, b) => {
                const da = a._timestamp ? (typeof a._timestamp.toDate === "function" ? a._timestamp.toDate() : new Date(a._timestamp)) : new Date(0);
                const db2 = b._timestamp ? (typeof b._timestamp.toDate === "function" ? b._timestamp.toDate() : new Date(b._timestamp)) : new Date(0);
                return db2 - da;
            });

            renderHistoryTable(list);
        }

        const DOC_SLUG_LABELS = {
            ic_front:        "IC Front",
            ic_back:         "IC Back",
            driving_licence: "Driving Licence",
            gdl_license:     "GDL License",
            vehicle_grant:   "Vehicle Grant",
            puspakom:        "PUSPAKOM Certificate",
            selfie:          "Live Selfie"
        };

        function renderHistoryTable(list) {
            const tbody = document.getElementById("complianceHistoryBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>No compliance history yet.</td></tr>";
                return;
            }

            for (const log of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                const actionLower = (log._action || "").toLowerCase();
                let badge = "";
                if (actionLower === "approved") {
                    badge = '<span class="inline-flex items-center px-3 py-1 rounded-full bg-emerald-600/20 text-emerald-400 text-xs font-semibold">Approved</span>';
                } else if (actionLower === "rejected") {
                    badge = '<span class="inline-flex items-center px-3 py-1 rounded-full bg-red-600/20 text-red-400 text-xs font-semibold">Rejected</span>';
                } else {
                    badge = `<span class="text-xs text-gray-400">${log._action}</span>`;
                }

                const hasSnapshot = log.DocumentSnapshot && typeof log.DocumentSnapshot === "object";
                const viewBtn = hasSnapshot
                    ? `<button type="button" class="view-snapshot-btn px-3 py-1 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-500 transition cursor-pointer" data-log-id="${log.id}">View</button>`
                    : '<span class="text-xs text-gray-500">-</span>';

                tr.innerHTML = `
                    <td class="py-3 px-4 text-gray-400">${formatDateTime(log._timestamp)}</td>
                    <td class="py-3 px-4">${formatContractorId(log._contractorId)}</td>
                    <td class="py-3 px-4">${log._name}</td>
                    <td class="py-3 px-4">${badge}</td>
                    <td class="py-3 px-4">${log._admin}</td>
                    <td class="py-3 px-4">${viewBtn}</td>
                `;
                tbody.appendChild(tr);
            }

            // Attach snapshot viewers
            tbody.querySelectorAll(".view-snapshot-btn").forEach(btn => {
                btn.addEventListener("click", () => {
                    const entry = complianceLogs.find(l => l.id === btn.dataset.logId);
                    if (entry) openSnapshotModal(entry);
                });
            });
        }

        // ── Snapshot modal ───────────────────────────────────────
        function openSnapshotModal(log) {
            const snap = log.DocumentSnapshot || {};
            const meta = snap.ComplianceDocumentsMetadata || {};
            const reviewedItems = log.ReviewedItems || [];
            const content = document.getElementById("snapshotContent");

            // Header info
            const actionLower = (log._action || "").toLowerCase();
            let actionBadge = "";
            if (actionLower === "approved") {
                actionBadge = '<span class="inline-flex items-center px-3 py-1 rounded-full bg-emerald-600/20 text-emerald-400 text-xs font-semibold">Approved</span>';
            } else if (actionLower === "rejected") {
                actionBadge = '<span class="inline-flex items-center px-3 py-1 rounded-full bg-red-600/20 text-red-400 text-xs font-semibold">Rejected</span>';
            }

            // Merge top-level URLs into metadata so each item renders once
            const allDocs = { ...meta };
            if (snap.SubmittedSelfieUrl && !allDocs.selfie) {
                allDocs.selfie = { url: snap.SubmittedSelfieUrl };
            }
            if (snap.IcFrontUrl && !allDocs.ic_front) {
                allDocs.ic_front = { url: snap.IcFrontUrl };
            }
            if (snap.IcBackUrl && !allDocs.ic_back) {
                allDocs.ic_back = { url: snap.IcBackUrl };
            }

            function buildDocCard(slug, docMeta) {
                const label = DOC_SLUG_LABELS[slug] || slug.replace(/_/g, " ").replace(/\b\w/g, ch => ch.toUpperCase());
                const url = docMeta.url || "";
                const isReviewed = reviewedItems.includes(slug);
                const dimClass = reviewedItems.length > 0 && !isReviewed ? "opacity-40" : "";
                const reviewedBadge = isReviewed
                    ? '<span class="px-2 py-0.5 rounded text-[10px] bg-emerald-600 text-white font-semibold">Reviewed</span>'
                    : "";

                const expiry = docMeta.expiry || docMeta.Expiry || docMeta.expiryDate || docMeta.ExpiryDate || "";
                let expiryStr = "N/A";
                if (expiry) {
                    const ed = typeof expiry.toDate === "function" ? expiry.toDate() : new Date(expiry);
                    if (!isNaN(ed.getTime())) {
                        expiryStr = `${String(ed.getDate()).padStart(2, "0")}/${String(ed.getMonth() + 1).padStart(2, "0")}/${ed.getFullYear()}`;
                    }
                }
                const hasExpiry = ["gdl_license", "vehicle_grant", "puspakom"].includes(slug);
                const expiryLine = hasExpiry ? `<p class="text-xs text-gray-400 mt-1">Expires: ${expiryStr}</p>` : "";

                const imageBlock = url
                    ? `<img src="${url}" alt="${label}" class="w-full h-40 object-cover" />`
                    : `<div class="w-full h-40 flex items-center justify-center bg-[#1a1a1a]"><span class="text-gray-600 text-xs">No image</span></div>`;

                return `
                    <div class="bg-[#262626] rounded-xl border border-[#333] overflow-hidden ${dimClass}">
                        ${imageBlock}
                        <div class="px-3 py-2">
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-semibold">${label}</span>
                                ${reviewedBadge}
                            </div>
                            ${expiryLine}
                        </div>
                    </div>`;
            }

            // Build all cards from the unified map — no duplicates
            let allCardsHtml = "";
            for (const [slug, docMeta] of Object.entries(allDocs)) {
                allCardsHtml += buildDocCard(slug, docMeta);
            }

            content.innerHTML = `
                <div class="flex flex-wrap items-center gap-4 mb-4">
                    <span class="text-sm text-gray-400">Contractor:</span>
                    <span class="text-sm font-semibold">${log._name}</span>
                    <span class="text-sm text-gray-400 ml-4">Action:</span>
                    ${actionBadge}
                    <span class="text-sm text-gray-400 ml-4">Admin:</span>
                    <span class="text-sm">${log._admin}</span>
                    <span class="text-sm text-gray-400 ml-4">Date:</span>
                    <span class="text-sm">${formatDateTime(log._timestamp)}</span>
                </div>

                <h4 class="text-sm font-semibold mb-3 text-gray-300">Frozen Document Evidence</h4>
                <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-4">
                    ${allCardsHtml}
                </div>
            `;

            document.getElementById("snapshotModal").classList.remove("hidden");
        }

        // Close modal
        document.getElementById("btnCloseSnapshot").addEventListener("click", () => {
            document.getElementById("snapshotModal").classList.add("hidden");
        });
        document.getElementById("snapshotModal").addEventListener("click", (e) => {
            if (e.target === document.getElementById("snapshotModal")) {
                document.getElementById("snapshotModal").classList.add("hidden");
            }
        });

        function setupHistorySearch() {
            const input = document.getElementById("historySearch");
            input.addEventListener("input", () => {
                historySearchTerm = input.value.toLowerCase();
                applyHistoryFilter();
            });
        }
    </script>

</asp:Content>

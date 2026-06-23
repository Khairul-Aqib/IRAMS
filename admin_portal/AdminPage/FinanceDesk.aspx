<%@ Page Title="Finance Desk" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="FinanceDesk.aspx.cs" Inherits="AdminPage.FinanceDesk" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Finance Desk
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-8 text-yellow-400">Finance Desk</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">

        <!-- header row -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Pending Withdrawals</h2>

            <div class="flex items-center gap-3">
                <!-- Search -->
                <div class="relative">
                    <input id="withdrawalSearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-72"
                           placeholder="Search by Name or Contractor ID" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>
            </div>
        </div>

        <!-- table -->
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Date</th>
                        <th class="py-3 px-4 text-left">Contractor ID</th>
                        <th class="py-3 px-4 text-left">Name</th>
                        <th class="py-3 px-4 text-left">Amount (RM)</th>
                        <th class="py-3 px-4 text-left">Bank Name</th>
                        <th class="py-3 px-4 text-left">Bank Account No.</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="withdrawalsTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- Withdrawal History Section -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6 mt-8">

        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Withdrawal History</h2>

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
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Date Requested</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Contractor ID</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Name</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Amount (RM)</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Bank Name</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Bank Account No.</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Date Processed</th>
                        <th class="py-3 px-4 text-left" style="position: sticky; top: 0; background-color: #1a1a1a; z-index: 1;">Processed By</th>
                    </tr>
                </thead>
                <tbody id="historyTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- Monthly Statements Section -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6 mt-8">

        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Monthly Statements</h2>

            <div class="flex items-center gap-3">
                <div class="relative">
                    <input id="statementSearch"
                           type="text"
                           class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-72"
                           placeholder="Search by Name or Contractor ID" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
                </div>
            </div>
        </div>

        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Contractor ID</th>
                        <th class="py-3 px-4 text-left">Name</th>
                        <th class="py-3 px-4 text-left">Email</th>
                        <th class="py-3 px-4 text-left">Completed Jobs</th>
                        <th class="py-3 px-4 text-left">Total Earnings (RM)</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="statementsTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <script type="module">
        import {
            collection,
            query,
            where,
            getDocs,
            onSnapshot,
            doc,
            getDoc,
            updateDoc,
            orderBy,
            serverTimestamp,
            limit
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        function getAdminName() {
            const el = document.querySelector('[id$="lblAdminName"]');
            const raw = el ? el.textContent.replace("(Admin)", "").trim() : "";
            return raw || "System Admin";
        }

        let withdrawals = [];
        let currentSearch = "";

        let historyWithdrawals = [];
        let historySearch = "";

        let statementContractors = [];
        let statementSearch = "";

        // ── Helpers ──────────────────────────────────────────────
        function formatContractorId(id) {
            if (!id) return "";
            if (id.length > 8) {
                const display = id.slice(0, 4) + "..." + id.slice(-4);
                return `<span title="${id}">${display}</span>`;
            }
            return `<span title="${id}">${id}</span>`;
        }

        function formatDate(value) {
            if (!value) return "";
            const d = typeof value.toDate === "function" ? value.toDate() : new Date(value);
            if (isNaN(d.getTime())) return value.toString();
            const day   = String(d.getDate()).padStart(2, "0");
            const month = String(d.getMonth() + 1).padStart(2, "0");
            const year  = d.getFullYear();
            const hours = String(d.getHours()).padStart(2, "0");
            const mins  = String(d.getMinutes()).padStart(2, "0");
            return `${day}/${month}/${year} ${hours}:${mins}`;
        }

        // ── Bootstrap ────────────────────────────────────────────
        document.addEventListener("firebase-auth-ready", () => {
            loadWithdrawals();
            setupSearch();
            loadWithdrawalHistory();
            setupHistorySearch();
            loadStatementContractors();
            setupStatementSearch();
        });

        // ── Load pending withdrawals + contractor details ────────
        function loadWithdrawals() {
            const tbody = document.getElementById("withdrawalsTableBody");
            tbody.innerHTML = "<tr><td colspan='7' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            onSnapshot(collection(db, "Withdrawals"), async (snap) => {

                withdrawals = [];
                const contractorCache = {};

                for (const docSnap of snap.docs) {
                    const w = { id: docSnap.id, ...docSnap.data() };

                    // Case-insensitive pending check (handles "pending", "Pending", "PENDING")
                    const status = (w.Status || w.status || "").toLowerCase();
                    if (status !== "pending") continue;

                    // Flexible field mapping: PascalCase (Admin) vs camelCase (Flutter)
                    const cid = w.ContractorID || w.contractorId || "";
                    if (cid && !contractorCache[cid]) {
                        try {
                            const cSnap = await getDoc(doc(db, "Contractor", cid));
                            contractorCache[cid] = cSnap.exists() ? cSnap.data() : {};
                        } catch {
                            contractorCache[cid] = {};
                        }
                    }

                    const contractor = contractorCache[cid] || {};

                    // Use withdrawal-level fields first (both casings), fall back to Contractor doc
                    w._name        = w.ContractorName || w.contractorName || contractor.FullName || "-";
                    w._displayId   = w.ContractorDisplayID || w.contractorDisplayId || contractor.ContractorID || cid;
                    w._bankName    = w.BankName || w.bankName || w.bank_name || contractor.BankName || contractor.bankName || "-";
                    w._bankAccount = w.BankAccountNo || w.bankAccountNo || w.BankAccount || w.bankAccount || w.accountNumber || w.AccountNumber || w.bank_account_no || contractor.BankAccountNo || contractor.bankAccountNo || contractor.BankAccount || contractor.bankAccount || "-";
                    w._amount      = w.Amount || w.amount || 0;
                    w._requestedAt = w.RequestedAt || w.requestedAt || null;

                    withdrawals.push(w);
                }

                // Update sidebar badge
                const badge = document.getElementById("financeBadge");
                if (badge) {
                    badge.textContent = withdrawals.length;
                    badge.classList.toggle("hidden", withdrawals.length === 0);
                }

                applyFilter();
            }, (err) => {
                console.error("Error loading withdrawals:", err);
                tbody.innerHTML = "<tr><td colspan='7' class='py-4 px-4 text-center text-red-400'>Failed to load withdrawals.</td></tr>";
            });
        }

        // ── Filter & render ──────────────────────────────────────
        function applyFilter() {
            let list = withdrawals.slice();

            if (currentSearch) {
                list = list.filter(w =>
                    (w._name || "").toLowerCase().includes(currentSearch) ||
                    (w._displayId || "").toLowerCase().includes(currentSearch)
                );
            }

            // Sort newest first
            list.sort((a, b) => {
                const da = a._requestedAt ? (typeof a._requestedAt.toDate === "function" ? a._requestedAt.toDate() : new Date(a._requestedAt)) : new Date(0);
                const db2 = b._requestedAt ? (typeof b._requestedAt.toDate === "function" ? b._requestedAt.toDate() : new Date(b._requestedAt)) : new Date(0);
                return db2 - da;
            });

            renderTable(list);
        }

        function renderTable(list) {
            const tbody = document.getElementById("withdrawalsTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='7' class='py-4 px-4 text-center text-gray-400'>No pending withdrawals.</td></tr>";
                return;
            }

            for (const w of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                const amount = parseFloat(w._amount).toFixed(2);

                tr.innerHTML = `
                    <td class="py-3 px-4 text-gray-400">${formatDate(w._requestedAt)}</td>
                    <td class="py-3 px-4">${formatContractorId(w._displayId)}</td>
                    <td class="py-3 px-4">${w._name}</td>
                    <td class="py-3 px-4 font-semibold text-yellow-400">RM ${amount}</td>
                    <td class="py-3 px-4">${w._bankName}</td>
                    <td class="py-3 px-4">${w._bankAccount}</td>
                    <td class="py-3 px-4">
                        <button type="button"
                                class="mark-paid-btn inline-flex items-center gap-1 px-4 py-1.5 rounded-lg bg-emerald-600 text-white text-xs font-semibold hover:bg-emerald-500 transition cursor-pointer"
                                data-id="${w.id}">
                            Mark as Paid
                        </button>
                    </td>
                `;
                tbody.appendChild(tr);
            }

            // Attach click handlers
            tbody.querySelectorAll(".mark-paid-btn").forEach(btn => {
                btn.addEventListener("click", () => markAsPaid(btn.dataset.id));
            });
        }

        // ── Mark as Paid ─────────────────────────────────────────
        async function markAsPaid(withdrawalId) {
            if (!confirm("Confirm this withdrawal has been paid?")) return;

            try {
                await updateDoc(doc(db, "Withdrawals", withdrawalId), {
                    Status: "completed",
                    ProcessedAt: serverTimestamp(),
                    ProcessedBy: getAdminName()
                });
                alert("Withdrawal marked as paid.");
            } catch (err) {
                console.error("Error updating withdrawal:", err);
                alert("Failed to update withdrawal status.");
            }
        }

        // ── Search ───────────────────────────────────────────────
        function setupSearch() {
            const input = document.getElementById("withdrawalSearch");
            input.addEventListener("input", () => {
                currentSearch = input.value.toLowerCase();
                applyFilter();
            });
        }

        // ══════════════════════════════════════════════════════════
        // ── Withdrawal History (Paid) ────────────────────────────
        // ══════════════════════════════════════════════════════════

        function loadWithdrawalHistory() {
            const tbody = document.getElementById("historyTableBody");
            tbody.innerHTML = "<tr><td colspan='8' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            const historyQuery = query(
                collection(db, "Withdrawals"),
                where("Status", "==", "completed"),
                orderBy("ProcessedAt", "desc"),
                limit(50)
            );

            onSnapshot(historyQuery, async (snap) => {
                historyWithdrawals = [];
                const contractorCache = {};

                for (const docSnap of snap.docs) {
                    const w = { id: docSnap.id, ...docSnap.data() };

                    const cid = w.ContractorID || w.contractorId || "";
                    if (cid && !contractorCache[cid]) {
                        try {
                            const cSnap = await getDoc(doc(db, "Contractor", cid));
                            contractorCache[cid] = cSnap.exists() ? cSnap.data() : {};
                        } catch {
                            contractorCache[cid] = {};
                        }
                    }

                    const contractor = contractorCache[cid] || {};

                    w._name        = w.ContractorName || w.contractorName || contractor.FullName || "-";
                    w._displayId   = w.ContractorDisplayID || w.contractorDisplayId || contractor.ContractorID || cid;
                    w._bankName    = w.BankName || w.bankName || w.bank_name || contractor.BankName || contractor.bankName || "-";
                    w._bankAccount = w.BankAccountNo || w.bankAccountNo || w.BankAccount || w.bankAccount || w.accountNumber || w.AccountNumber || w.bank_account_no || contractor.BankAccountNo || contractor.bankAccountNo || contractor.BankAccount || contractor.bankAccount || "-";
                    w._amount      = w.Amount || w.amount || 0;
                    w._requestedAt = w.RequestedAt || w.requestedAt || w.RequestedTime || w.requestedTime || w.CreatedAt || w.createdAt || null;
                    w._processedAt = w.ProcessedAt || w.processedAt || null;
                    w._processedBy = w.ProcessedBy || w.processedBy || "-";

                    historyWithdrawals.push(w);
                }

                applyHistoryFilter();
            }, (err) => {
                console.error("Error loading withdrawal history:", err);
                tbody.innerHTML = "<tr><td colspan='8' class='py-4 px-4 text-center text-red-400'>Failed to load withdrawal history.</td></tr>";
            });
        }

        function applyHistoryFilter() {
            let list = historyWithdrawals.slice();

            if (historySearch) {
                list = list.filter(w =>
                    (w._name || "").toLowerCase().includes(historySearch) ||
                    (w._displayId || "").toLowerCase().includes(historySearch)
                );
            }

            // Sort newest first
            list.sort((a, b) => {
                const da = a._requestedAt ? (typeof a._requestedAt.toDate === "function" ? a._requestedAt.toDate() : new Date(a._requestedAt)) : new Date(0);
                const db2 = b._requestedAt ? (typeof b._requestedAt.toDate === "function" ? b._requestedAt.toDate() : new Date(b._requestedAt)) : new Date(0);
                return db2 - da;
            });

            renderHistoryTable(list);
        }

        function renderHistoryTable(list) {
            const tbody = document.getElementById("historyTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='8' class='py-4 px-4 text-center text-gray-400'>No paid withdrawals yet.</td></tr>";
                return;
            }

            for (const w of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                const amount = parseFloat(w._amount).toFixed(2);
                const processedDate = w._processedAt ? formatDate(w._processedAt) : "-";
                const processedBy = w._processedBy || "-";

                tr.innerHTML = `
                    <td class="py-3 px-4 text-gray-400">${formatDate(w._requestedAt)}</td>
                    <td class="py-3 px-4">${formatContractorId(w._displayId)}</td>
                    <td class="py-3 px-4">${w._name}</td>
                    <td class="py-3 px-4 font-semibold text-yellow-400">RM ${amount}</td>
                    <td class="py-3 px-4">${w._bankName}</td>
                    <td class="py-3 px-4">${w._bankAccount}</td>
                    <td class="py-3 px-4 text-gray-400">${processedDate}</td>
                    <td class="py-3 px-4">${processedBy}</td>
                `;
                tbody.appendChild(tr);
            }
        }

        function setupHistorySearch() {
            const input = document.getElementById("historySearch");
            input.addEventListener("input", () => {
                historySearch = input.value.toLowerCase();
                applyHistoryFilter();
            });
        }

        // ══════════════════════════════════════════════════════════
        // ── Monthly Statements ───────────────────────────────────
        // ══════════════════════════════════════════════════════════

        function loadStatementContractors() {
            const tbody = document.getElementById("statementsTableBody");
            tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>Loading contractors...</td></tr>";

            onSnapshot(collection(db, "Contractor"), async (snap) => {
                statementContractors = [];

                for (const docSnap of snap.docs) {
                    const c = { id: docSnap.id, ...docSnap.data() };

                    // Skip soft-deleted contractors
                    if (c.IsDeleted === true) continue;

                    // Query all invoices for this contractor, then filter client-side
                    // to handle legacy docs that may lack a Status field
                    const invoiceQuery = query(
                        collection(db, "JobInvoice"),
                        where("ContractorID", "==", docSnap.id)
                    );
                    const invoiceSnap = await getDocs(invoiceQuery);

                    let totalEarnings = 0;
                    let totalJobs = 0;

                    invoiceSnap.forEach(inv => {
                        const data = inv.data();
                        // Count as completed if Status is 'Completed', OR if Status
                        // is missing entirely and PaymentStatus is 'Paid' (legacy data)
                        if (data.Status === "Completed" || (!data.Status && data.PaymentStatus === "Paid")) {
                            totalEarnings += parseFloat(data.TotalCost || 0);
                            totalJobs++;
                        }
                    });

                    c._totalEarnings = totalEarnings;
                    c._totalJobs = totalJobs;
                    statementContractors.push(c);
                }

                applyStatementFilter();
            }, (err) => {
                console.error("Error loading statement contractors:", err);
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-red-400'>Failed to load contractors.</td></tr>";
            });
        }

        function applyStatementFilter() {
            let list = statementContractors.slice();

            if (statementSearch) {
                list = list.filter(c =>
                    (c.FullName || "").toLowerCase().includes(statementSearch) ||
                    (c.ContractorID || "").toLowerCase().includes(statementSearch)
                );
            }

            list.sort((a, b) => (a.FullName || "").localeCompare(b.FullName || ""));
            renderStatementTable(list);
        }

        function renderStatementTable(list) {
            const tbody = document.getElementById("statementsTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>No contractors found.</td></tr>";
                return;
            }

            for (const c of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                tr.innerHTML = `
                    <td class="py-3 px-4">${formatContractorId(c.ContractorID || c.id)}</td>
                    <td class="py-3 px-4">${c.FullName || "-"}</td>
                    <td class="py-3 px-4">${c.Email || "-"}</td>
                    <td class="py-3 px-4">${c._totalJobs}</td>
                    <td class="py-3 px-4 font-semibold text-yellow-400">RM ${c._totalEarnings.toFixed(2)}</td>
                    <td class="py-3 px-4">
                        <button type="button"
                                class="send-statement-btn inline-flex items-center gap-1 px-4 py-1.5 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-500 transition cursor-pointer"
                                data-id="${c.id}"
                                data-email="${c.Email || ""}"
                                data-name="${c.FullName || ""}"
                                data-jobs="${c._totalJobs}"
                                data-earnings="${c._totalEarnings.toFixed(2)}">
                            Send Monthly Statement
                        </button>
                    </td>
                `;
                tbody.appendChild(tr);
            }

            tbody.querySelectorAll(".send-statement-btn").forEach(btn => {
                btn.addEventListener("click", () => {
                    sendMonthlyStatement(
                        btn.dataset.id,
                        btn.dataset.email,
                        btn.dataset.name,
                        btn
                    );
                });
            });
        }

        function setupStatementSearch() {
            const input = document.getElementById("statementSearch");
            input.addEventListener("input", () => {
                statementSearch = input.value.toLowerCase();
                applyStatementFilter();
            });
        }

        // ── Send Monthly Statement via EmailJS ──────────────────
        async function sendMonthlyStatement(contractorId, contractorEmail, contractorName, btnElement) {
            if (!contractorEmail) {
                alert("No email address on file for this contractor.");
                return;
            }

            if (!confirm(`Send monthly statement to ${contractorName} (${contractorEmail})?`)) return;

            // Show loading state on button
            const originalText = btnElement.textContent;
            btnElement.textContent = "Sending...";
            btnElement.disabled = true;
            btnElement.classList.add("opacity-50", "cursor-not-allowed");

            try {
                const now = new Date();
                const currentMonth = now.getMonth();
                const currentYear = now.getFullYear();

                // Fetch the contractor doc for contractor_type
                const contractorSnap = await getDoc(doc(db, "Contractor", contractorId));
                const contractorData = contractorSnap.exists() ? contractorSnap.data() : {};
                const contractorType = contractorData.CompanyName || contractorData.companyName
                    || contractorData.BusinessName || contractorData.businessName
                    || "Self-Employed";

                // Query both ContractorID (PascalCase) and contractorId (camelCase)
                const q1 = query(collection(db, "JobInvoice"), where("ContractorID", "==", contractorId));
                const q2 = query(collection(db, "JobInvoice"), where("contractorId", "==", contractorId));
                const [snap1, snap2] = await Promise.all([getDocs(q1), getDocs(q2)]);

                // Merge results, deduplicate by doc ID
                const seen = new Set();
                const allDocs = [];
                for (const s of [snap1, snap2]) {
                    s.forEach(d => {
                        if (!seen.has(d.id)) { seen.add(d.id); allDocs.push(d); }
                    });
                }

                // Also check the Jobs collection as a fallback
                const jq1 = query(collection(db, "Jobs"), where("ContractorAssigned", "==", contractorId));
                const jq2 = query(collection(db, "Jobs"), where("contractorAssigned", "==", contractorId));
                const [jSnap1, jSnap2] = await Promise.all([getDocs(jq1), getDocs(jq2)]);
                for (const s of [jSnap1, jSnap2]) {
                    s.forEach(d => {
                        if (!seen.has(d.id)) { seen.add(d.id); allDocs.push(d); }
                    });
                }

                // Helper: format a JS Date as DD/MM/YYYY (ASCII-safe)
                function formatDateSafe(d) {
                    const dd = String(d.getDate()).padStart(2, "0");
                    const mm = String(d.getMonth() + 1).padStart(2, "0");
                    const yyyy = d.getFullYear();
                    return dd + "/" + mm + "/" + yyyy;
                }

                let totalEarnings = 0;
                let totalJobs = 0;
                let jobRows = [];

                for (const docSnap of allDocs) {
                    const data = docSnap.data();

                    // Case-insensitive status check
                    const status = (data.Status || data.status || "").toLowerCase();
                    const payStatus = (data.PaymentStatus || data.paymentStatus || "").toLowerCase();

                    if (status !== "completed" && payStatus !== "paid") continue;

                    // Parse the completion date (CompletedAt preferred, RequestedTime as fallback)
                    let rawDate = data.CompletedAt || data.completedAt || data.RequestedTime || data.requestedTime;
                    let jobDate = rawDate ? (typeof rawDate.toDate === 'function' ? rawDate.toDate() : new Date(rawDate)) : null;
                    let dateString = jobDate ? jobDate.toLocaleDateString('en-GB') : 'N/A';

                    const cost = parseFloat(data.TotalCost || data.totalCost || 0);

                    // Try current-month filter, but track all completed jobs as fallback
                    const isCurrentMonth = jobDate && !isNaN(jobDate.getTime())
                        && jobDate.getMonth() === currentMonth
                        && jobDate.getFullYear() === currentYear;

                    jobRows.push({
                        date: jobDate && !isNaN(jobDate.getTime()) ? jobDate : null,
                        dateString: dateString,
                        service: data.ServiceType || data.serviceType || "-",
                        amount: cost,
                        isCurrentMonth: isCurrentMonth
                    });
                }

                // If we have current-month jobs, show only those; otherwise fall back to all
                let currentMonthRows = jobRows.filter(r => r.isCurrentMonth);
                let finalRows = currentMonthRows.length > 0 ? currentMonthRows : jobRows;

                for (const row of finalRows) {
                    totalEarnings += row.amount;
                    totalJobs++;
                }

                // Sort by date ascending (nulls at end)
                finalRows.sort((a, b) => {
                    if (!a.date && !b.date) return 0;
                    if (!a.date) return 1;
                    if (!b.date) return -1;
                    return a.date - b.date;
                });

                // Build HTML table rows for the job breakdown
                const tdStyle = 'style="padding: 10px 5px; border-bottom: 1px solid #eee; font-size: 14px;"';
                const tdAmountStyle = 'style="padding: 10px 5px; border-bottom: 1px solid #eee; font-size: 14px; text-align: right;"';
                let jobBreakdownHtml = "";

                if (finalRows.length === 0) {
                    jobBreakdownHtml = '<tr><td colspan="3" style="padding: 10px 5px; font-size: 14px; text-align: center; color: #999;">No completed jobs this month.</td></tr>';
                } else {
                    for (const row of finalRows) {
                        jobBreakdownHtml += '<tr>'
                            + '<td ' + tdStyle + '>' + row.dateString + '</td>'
                            + '<td ' + tdStyle + '>' + row.service + '</td>'
                            + '<td ' + tdAmountStyle + '>RM ' + row.amount.toFixed(2) + '</td>'
                            + '</tr>';
                    }
                }

                // Build the statement month string (e.g., "May 2026")
                const statementMonth = now.toLocaleString("en-US", { month: "long", year: "numeric" });

                const templateParams = {
                    to_email:            contractorEmail,
                    contractor_name:     contractorName,
                    contractor_type:     contractorType,
                    statement_month:     statementMonth,
                    total_jobs:          totalJobs,
                    total_earnings:      totalEarnings.toFixed(2),
                    job_breakdown_html:  jobBreakdownHtml
                };

                await emailjs.send(
                    "service_vog61xa",
                    "template_r2d455i",
                    templateParams
                );

                alert(`Statement sent successfully to ${contractorName} (${contractorEmail})!`);
            } catch (err) {
                console.error("Error sending statement:", err);
                alert("Failed to send statement. Please check your EmailJS configuration and try again.");
            } finally {
                // Restore button state
                btnElement.textContent = originalText;
                btnElement.disabled = false;
                btnElement.classList.remove("opacity-50", "cursor-not-allowed");
            }
        }
    </script>

</asp:Content>

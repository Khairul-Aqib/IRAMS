<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true" CodeBehind="ContractorPerformance.aspx.cs" Inherits="AdminPage.ContractorPerformance" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Contractor Performance Report
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
    <script type="module">
        import {
            collection,
            query,
            where,
            getDocs,
            onSnapshot
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        document.addEventListener("firebase-auth-ready", async () => {

            if (document.readyState === "loading") {
                await new Promise(resolve => document.addEventListener("DOMContentLoaded", resolve));
            }

            const PAGE_SIZE = 10;
            let rows = [];
            let currentPage = 1;

            function parseTS(value) {
                if (!value) return null;
                try {
                    if (typeof value.toDate === "function") return value.toDate();
                    const d = new Date(value);
                    return isNaN(d.getTime()) ? null : d;
                } catch {
                    return null;
                }
            }

            function formatDate(d) {
                if (!d) return "N/A";
                return d.toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' });
            }

            function formatPercent(n) {
                if (n == null || isNaN(n)) return "0%";
                return `${Math.round(n * 100)}%`;
            }

            function safeNum(v) {
                const n = Number(v);
                return isNaN(n) ? 0 : n;
            }

            function renderSummary(totalContractors, activeContractors, avgRating, topContractorName) {
                document.getElementById("totalContractors").textContent = totalContractors;
                document.getElementById("activeContractors").textContent = activeContractors;
                document.getElementById("contractorRating").textContent = avgRating ? avgRating.toFixed(2) : "N/A";
                document.getElementById("topContractor").textContent = topContractorName || "N/A";
            }

            function renderTablePage(page = 1) {
                currentPage = page;
                const tbody = document.getElementById("contractorTableBody");
                tbody.innerHTML = "";

                if (!rows.length) {
                    tbody.innerHTML = `<tr><td colspan="8" class="py-6 text-center text-gray-400">No contractors</td></tr>`;
                    renderPager();
                    return;
                }

                const start = (page - 1) * PAGE_SIZE;
                const pageItems = rows.slice(start, start + PAGE_SIZE);

                const dim = "text-gray-600";
                for (const r of pageItems) {
                    const services = r.ServiceTypes.length
                        ? r.ServiceTypes.map(s => `<span class="service-badge">${s}</span>`).join("")
                        : `<span class="${dim}">—</span>`;
                    const completedCls = r.TotalCompleted === 0 ? dim : "";
                    const acceptCls = r.AcceptanceRate === 0 ? dim : "";
                    const ratingCls = r.AvgRating == null ? dim : "";
                    const earnCls = safeNum(r.TotalEarnings) === 0 ? dim : "";
                    const activeCls = !r.LastActive ? dim : "";

                    tbody.innerHTML += `
                    <tr class="border-b border-[#333]">
                        <td class="py-3 align-top">${r.Name}</td>
                        <td class="py-3 align-top service-types-cell">${services}</td>
                        <td class="py-3 align-top text-right ${completedCls}">${r.TotalCompleted}</td>
                        <td class="py-3 align-top text-right ${acceptCls}">${formatPercent(r.AcceptanceRate)}</td>
                        <td class="py-3 align-top text-right">${formatPercent(r.CancellationRate)}</td>
                        <td class="py-3 align-top text-right ${ratingCls}">${r.AvgRating != null ? r.AvgRating.toFixed(1) : "N/A"}</td>
                        <td class="py-3 align-top text-right ${earnCls}">RM ${safeNum(r.TotalEarnings).toFixed(2)}</td>
                        <td class="py-3 align-top text-right ${activeCls}">${r.LastActive ? formatDate(r.LastActive) : "N/A"}</td>
                    </tr>
                `;
                }

                renderPager();
            }

            function renderPager() {
                const pager = document.getElementById("Pager");
                pager.innerHTML = "";
                const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));

                // pages
                const maxShow = 7;
                let start = Math.max(1, currentPage - Math.floor(maxShow / 2));
                let end = Math.min(totalPages, start + maxShow - 1);
                if (end - start + 1 < maxShow) start = Math.max(1, end - maxShow + 1);

                for (let p = start; p <= end; p++) {
                    pager.innerHTML += `<button ${p === currentPage ? 'disabled' : ''} onclick="window.contractorGoToPage(${p})" class="mx-1 px-3 py-1 rounded-full ${p === currentPage ? 'bg-yellow-400 text-black' : 'bg-[#222]'}">${p}</button>`;
                }
            }

            // expose pager function globally so the inline onclick can call it
            window.contractorGoToPage = (p) => {
                const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
                if (p < 1 || p > totalPages) return;
                renderTablePage(p);
            };

            // CSV export
            function exportCsv() {
                if (!rows.length) return alert("No data to export");
                const headers = ["ContractorName", "ServiceTypes", "TotalCompleted", "AcceptanceRate", "CancellationRate", "AverageRating", "TotalEarnings", "LastActive"];
                const csvRows = [headers.join(",")];

                for (const r of rows) {
                    const cols = [
                        `"${(r.Name || '').toString().replace(/"/g, '""')}"`,
                        `"${(r.ServiceTypes || []).join('; ').replace(/"/g, '""')}"`,
                        r.TotalCompleted,
                        `${Math.round((r.AcceptanceRate || 0) * 100)}%`,
                        `${Math.round((r.CancellationRate || 0) * 100)}%`,
                        r.AvgRating != null ? r.AvgRating.toFixed(2) : "",
                        safeNum(r.TotalEarnings).toFixed(2),
                        r.LastActive ? formatDate(r.LastActive) : ""
                    ];
                    csvRows.push(cols.join(","));
                }

                const blob = new Blob([csvRows.join("\n")], { type: "text/csv;charset=utf-8;" });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = `contractor_performance_${new Date().toISOString().slice(0, 10)}.csv`;
                a.click();
                URL.revokeObjectURL(url);
            }

            const exportBtn = document.getElementById("exportContractorCSV");
            if (exportBtn) {
                exportBtn.addEventListener("click", (e) => {
                    e.preventDefault();
                    exportCsv();
                });
            } else {
                console.warn("exportContractorCSV element not found.");
            }

            // ContractorAssigned on Jobs may be a DocumentReference, a string path, or a bare id
            function extractContractorId(ref) {
                if (!ref) return null;
                if (typeof ref === 'object' && ref.path) return ref.path.split('/').pop();
                if (typeof ref === 'string' && ref.includes('/')) return ref.split('/').pop();
                return typeof ref === 'string' ? ref : String(ref);
            }

            //Main aggregation logic (real-time)
            function loadContractorPerformance() {
                onSnapshot(collection(db, "Contractor"), async (contractorsSnap) => {
                rows = [];

                // Load all jobs once and group by contractor id
                const jobsSnap = await getDocs(collection(db, "Jobs"));
                const jobsByContractor = {};
                for (const j of jobsSnap.docs) {
                    const d = j.data();
                    const cId = extractContractorId(d.ContractorAssigned);
                    if (!cId) continue;
                    (jobsByContractor[cId] ||= []).push(d);
                }

                for (const cDoc of contractorsSnap.docs) {
                    const cId = cDoc.id;
                    const cData = cDoc.data();
                    const name = cData.FullName || cData.Name || cId;

                    const jobs = jobsByContractor[cId] || [];
                    let totalAssigned = jobs.length;
                    let accepted = 0;
                    let cancelled = 0;
                    let completed = 0;
                    let ratingSum = 0;
                    let ratingCount = 0;
                    let totalEarnings = 0;
                    const serviceSet = new Set();
                    let lastActive = null;

                    for (const d of jobs) {
                        const st = (d.Status || "").toString().toLowerCase();

                        // Count as accepted if status is Accepted, Completed, or In Progress
                        if (st === "accepted" || st === "completed" ||
                            st === "in progress" || st === "on the way") {
                            accepted++;
                        }

                        if (st === "cancelled") {
                            cancelled++;
                        }

                        if (st === "completed") {
                            completed++;
                            // earnings counted on completed jobs only
                            totalEarnings += safeNum(d.TotalCost);
                        }

                        // rating
                        const rRaw = d.UserRating ?? d.userRating ?? d.Rating ?? d.rating;
                        if (rRaw != null && rRaw !== '') {
                            const rn = Number(rRaw);
                            if (!isNaN(rn)) {
                                ratingSum += rn;
                                ratingCount++;
                            }
                        }

                        if (d.ServiceType) serviceSet.add(d.ServiceType);

                        // last active: prefer CompletionTime -> StartTime -> DateRequested
                        const comp = parseTS(d.CompletionTime);
                        const stt = parseTS(d.StartTime);
                        const req = parseTS(d.DateRequested) || parseTS(d.RequestedTime);
                        const candidate = comp || stt || req;
                        if (candidate) {
                            if (!lastActive || candidate.getTime() > lastActive.getTime()) lastActive = candidate;
                        }
                    }

                    const avgRating = ratingCount ? (ratingSum / ratingCount) : null;

                    const acceptanceRate = totalAssigned ? (accepted / totalAssigned) : 0;

                    // Cancellation Rate: (Jobs Cancelled) / (Total Jobs Assigned)
                    const cancellationRate = totalAssigned ? (cancelled / totalAssigned) : 0;

                    rows.push({
                        ContractorID: cId,
                        Name: name,
                        ServiceTypes: Array.from(serviceSet),
                        TotalCompleted: completed,
                        AcceptanceRate: acceptanceRate,
                        CancellationRate: cancellationRate,
                        AvgRating: avgRating,
                        TotalEarnings: totalEarnings,
                        LastActive: lastActive
                    });
                }

                const totalContractors = rows.length;
                const activeContractors = rows.filter(r => r.TotalCompleted > 0).length;
                const avgRatingAll = (() => {
                    let sum = 0, cnt = 0;
                    for (const r of rows) if (r.AvgRating != null) { sum += r.AvgRating; cnt++; }
                    return cnt ? (sum / cnt) : null;
                })();

                // top contractor by completed jobs
                const top = rows.slice().sort((a, b) => b.TotalCompleted - a.TotalCompleted)[0];
                const topName = top ? `${top.Name} (${top.TotalCompleted})` : "N/A";
                rows.sort((a, b) => b.TotalCompleted - a.TotalCompleted);

                renderSummary(totalContractors, activeContractors, avgRatingAll, topName);
                renderTablePage(1);
                }, (err) => {
                    console.error("Contractor load error", err);
                });
            }

            loadContractorPerformance();

        });
    </script>
</asp:Content>


<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-semibold mb-6">Reports</h1>

    <div class="flex gap-8 mb-6 border-b border-[#333] pb-2">
        <a href="RevenueReports.aspx" class="text-gray-400 cursor-pointer">Revenue Report
        </a>
        <a href="JobPerformance.aspx" class="text-gray-400 cursor-pointer">Job Performance Report
        </a>
        <a href="ContractorPerformance.aspx" class="text-yellow-400 font-semibold cursor-pointer">Contractor Performance Report
        </a>
        <a href="UserActivity.aspx" class="text-gray-400 cursor-pointer">User Activity Report
        </a>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Total Contractors</p>
            <h2 class="text-3xl font-bold text-yellow-400"><span id="totalContractors">0</span></h2>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Active Contractors</p>
            <h2 class="text-3xl font-bold text-green-400"><span id="activeContractors">0</span></h2>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Average Contractor Rating</p>
            <h2 class="text-3xl font-bold text-red-400"><span id="contractorRating">0</span></h2>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Top Contrctor</p>
            <h2 class="text-3xl font-bold text-yellow-400"><span id="topContractor">N/A</span></h2>
        </div>
    </div>

    <!-- Contractor Performance Table -->
    <div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333]">
        <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl font-semibold">Contractor Performance Report</h2>

            <div class="flex gap-3 items-center">
                <i data-lucide="filter" class="w-6 h-6 text-gray-400 cursor-pointer"></i>
                <div class="relative">
                    <input id="contractorSearch" class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4 pl-10"
                        placeholder="Search (Name or ID)" />
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-5 h-5 text-gray-400"></i>
                </div>
            </div>
        </div>

        <style>
            .contractor-perf-table { table-layout: fixed; }
            .contractor-perf-table th,
            .contractor-perf-table td { padding-left: 0.5rem; padding-right: 0.5rem; }
            .contractor-perf-table th:first-child,
            .contractor-perf-table td:first-child { padding-left: 0; }
            .contractor-perf-table th:last-child,
            .contractor-perf-table td:last-child { padding-right: 0; }
            .service-types-col { width: 250px; max-width: 250px; }
            .service-types-cell {
                white-space: normal;
                line-height: 1.4;
                max-width: 250px;
            }
            .service-badge {
                display: inline-block;
                background: rgba(250, 204, 21, 0.12);
                color: #facc15;
                border: 1px solid rgba(250, 204, 21, 0.3);
                padding: 2px 8px;
                border-radius: 9999px;
                font-size: 0.75rem;
                margin: 2px 4px 2px 0;
                white-space: nowrap;
            }
        </style>

        <table class="w-full text-sm contractor-perf-table">
            <thead class="text-gray-400 border-b border-[#333]">
                <tr>
                    <th class="pb-3 text-left">Contractor Name</th>
                    <th class="pb-3 text-left service-types-col">Service Types</th>
                    <th class="pb-3 text-right">Total Jobs Completed</th>
                    <th class="pb-3 text-right">Acceptance Rate (%)</th>
                    <th class="pb-3 text-right">Cancellation Rate (%)</th>
                    <th class="pb-3 text-right">Average Rating</th>
                    <th class="pb-3 text-right">Total Earnings (RM)</th>
                    <th class="pb-3 text-right">Last Active Date</th>
                </tr>
            </thead>
            <tbody id="contractorTableBody"></tbody>
        </table>

        <div id="Pager" class="flex justify-center w-full gap-2 mt-6"></div>
        <div class="text-right mt-4">
            <a href="#" id="exportCSV" class="text-red-400 hover:underline">Export (CSV)</a>
        </div>
    </div>

</asp:Content>

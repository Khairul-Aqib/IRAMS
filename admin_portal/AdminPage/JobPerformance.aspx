<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true"
    CodeBehind="JobPerformance.aspx.cs" Inherits="AdminPage.JobPerformance" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Job Performance Report
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
<script type="module">
    import {
        collection,
        onSnapshot
    } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

    document.addEventListener("firebase-auth-ready", async () => {

        const PAGE_SIZE = 10;
        let allRows = [];
        let currentPage = 1;

        /* ================= HELPERS ================= */
        function parseTS(val) {
            if (!val) return null;
            if (typeof val.toDate === "function") return val.toDate();
            const d = new Date(val);
            return isNaN(d.getTime()) ? null : d;
        }

        function formatDT(date) {
            if (!date) return "N/A";
            return date.toLocaleString("en-MY", {
                year: "numeric",
                month: "2-digit",
                day: "2-digit",
                hour: "2-digit",
                minute: "2-digit"
            });
        }

        function formatDuration(ms) {
            if (!ms || ms <= 0) return "N/A";
            const mins = Math.round(ms / 60000);
            const h = Math.floor(mins / 60);
            const m = mins % 60;
            return h === 0 ? `${m} mins` : `${h} hr ${m} mins`;
        }

        /* ================= SUMMARY ================= */
        function renderSummary(total, completed, cancelled, avgMs) {
            document.getElementById("totalJobs").textContent = total;
            document.getElementById("completedJobs").textContent = completed;
            document.getElementById("cancelledJobs").textContent = cancelled;
            document.getElementById("avgCompletionTime").textContent =
                avgMs ? formatDuration(avgMs) : "N/A";
        }

        /* ================= TABLE ================= */
        function renderPage(page) {
            currentPage = page;
            const tbody = document.getElementById("jobTableBody");
            tbody.innerHTML = "";

            const start = (page - 1) * PAGE_SIZE;
            const items = allRows.slice(start, start + PAGE_SIZE);

            if (!items.length) {
                tbody.innerHTML = `
                <tr>
                    <td colspan="9" class="text-center py-4 text-gray-400">No data</td>
                </tr>`;
                return;
            }

            for (const r of items) {
                tbody.innerHTML += `
            <tr class="border-b border-[#333]">
                <td class="py-3">${r.jobId}</td>
                <td class="py-3">${r.service}</td>
                <td class="py-3">${r.status}</td>
                <td class="py-3">${formatDT(r.requested)}</td>
                <td class="py-3">${formatDT(r.accepted)}</td>
                <td class="py-3">${formatDT(r.completed)}</td>
                <td class="py-3">${formatDuration(r.duration)}</td>
                <td class="py-3">${r.rating}</td>
                <td class="py-3">${r.cancellation}</td>
            </tr>`;
            }

            renderPager();
        }

        function renderPager() {
            const pager = document.getElementById("pager");
            pager.innerHTML = "";
            const pages = Math.ceil(allRows.length / PAGE_SIZE);

            for (let i = 1; i <= pages; i++) {
                pager.innerHTML += `
                <button onclick="window.goToPage(${i})"
                    class="mx-1 px-3 py-1 rounded-full ${i === currentPage
                        ? "bg-yellow-400 text-black"
                        : "bg-[#222] text-gray-300"}">
                    ${i}
                </button>`;
            }
        }

        window.goToPage = (p) => renderPage(p);

        /* ================= DATA LOAD ================= */
        // Drive the page off the Jobs collection directly. JobInvoice records
        // only exist for completed jobs, so iterating it dropped every cancelled
        // job from the counts and the table.
        function loadJobPerformance() {
            onSnapshot(collection(db, "Jobs"), (jobsSnap) => {

                let completedCount = 0;
                let cancelledCount = 0;
                let durationSum = 0;
                let durationCount = 0;

                allRows = [];

                for (const jobDoc of jobsSnap.docs) {
                    const job = jobDoc.data();
                    const jobId = jobDoc.id;

                    // Status / Service: Jobs uses PascalCase, but fall back to
                    // camelCase in case the mobile app ever writes that variant.
                    const status  = job.Status      || job.status      || "Pending";
                    const service = job.ServiceType || job.serviceType || "—";

                    // Rating / cancellation reason — field name in the mobile app
                    // wasn't confirmed, so try common variants.
                    const ratingRaw = job.UserRating ?? job.userRating ?? job.rating;
                    const rating = (ratingRaw === null || ratingRaw === undefined || ratingRaw === "")
                        ? "No Rating"
                        : ratingRaw;

                    const cancellation =
                        job.CancellationReason || job.cancellationReason || "N/A";

                    const requested = parseTS(job.DateRequested);
                    const accepted  = parseTS(job.DateAccepted);
                    const completed = parseTS(job.DateCompleted);

                    let durationMs = null;
                    if (accepted && completed) {
                        durationMs = completed - accepted;
                        if (durationMs > 0) {
                            durationSum += durationMs;
                            durationCount++;
                        }
                    }

                    if (status === "Completed") completedCount++;
                    if (status === "Cancelled") cancelledCount++;

                    allRows.push({
                        jobId,
                        service,
                        status,
                        requested,
                        accepted,
                        completed,
                        duration: durationMs,
                        rating,
                        cancellation
                    });
                }

                const avg = durationCount ? durationSum / durationCount : null;

                renderSummary(allRows.length, completedCount, cancelledCount, avg);
                renderPage(1);
            });
        }

        loadJobPerformance();
    });
</script>

</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">
<h1 class="text-3xl font-semibold mb-6">Reports</h1>

<div class="flex gap-8 mb-6 border-b border-[#333] pb-2">
    <a href="RevenueReports.aspx" class="text-gray-400">Revenue Report</a>
    <a href="JobPerformance.aspx" class="text-yellow-400 font-semibold">Job Performance Report</a>
    <a href="ContractorPerformance.aspx" class="text-gray-400">Contractor Performance Report</a>
    <a href="UserActivity.aspx" class="text-gray-400">User Activity Report</a>
</div>

<!-- Summary Cards -->
<div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
    <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
        <p class="text-sm text-gray-400">Total Jobs</p>
        <h2 class="text-3xl font-bold text-yellow-400"><span id="totalJobs">0</span></h2>
    </div>
    <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
        <p class="text-sm text-gray-400">Completed Jobs</p>
        <h2 class="text-3xl font-bold text-green-400"><span id="completedJobs">0</span></h2>
    </div>
    <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
        <p class="text-sm text-gray-400">Cancelled Jobs</p>
        <h2 class="text-3xl font-bold text-red-400"><span id="cancelledJobs">0</span></h2>
    </div>
    <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
        <p class="text-sm text-gray-400">Average Completion Time</p>
        <h2 class="text-3xl font-bold text-yellow-400"><span id="avgCompletionTime">N/A</span></h2>
    </div>
</div>

<!-- Table -->
<div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333]">
    <h2 class="text-xl font-semibold mb-6">Job Performance Report</h2>
    <table class="w-full text-sm">
        <thead class="text-gray-400 border-b border-[#333]">
            <tr>
                <th class="pb-3 text-left">Job ID</th>
                <th class="pb-3 text-left">Service Type</th>
                <th class="pb-3 text-left">Status</th>
                <th class="pb-3 text-left">Requested Time</th>
                <th class="pb-3 text-left">Start Time</th>
                <th class="pb-3 text-left">Completion Time</th>
                <th class="pb-3 text-left">Duration</th>
                <th class="pb-3 text-left">User Rating</th>
                <th class="pb-3 text-left">Cancellation Reason</th>
            </tr>
        </thead>
        <tbody id="jobTableBody"></tbody>
    </table>

    <div class="flex justify-center mt-6" id="pager"></div>
    <div class="text-right mt-4">
        <a href="#" class="text-red-400 hover:underline">Export (CSV)</a>
    </div>
</div>
</asp:Content>

<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true" CodeBehind="RevenueReports.aspx.cs" Inherits="AdminPage.Reports" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Revenue Reports
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
    <script type="module">
        import {
            collection,
            getDocs,
            onSnapshot,
            doc,
            getDoc,
            query,
            orderBy
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        document.addEventListener("firebase-auth-ready", async () => {

            const PAGE_SIZE = 10;
            let rows = [];
            let currentPage = 1;

            const table = document.getElementById("revenueTable");

            const fmtMoney = (n) => (Number(n) || 0).toFixed(2);

            function renderPage(page) {
                currentPage = page;
                table.innerHTML = "";

                const start = (page - 1) * PAGE_SIZE;
                const pageRows = rows.slice(start, start + PAGE_SIZE);

                for (const inv of pageRows) {
                    table.innerHTML += `
                    <tr class="border-b border-[#333]">
                        <td class="py-3">${inv.JobID}</td>
                        <td class="py-3">${inv.ServiceType}</td>
                        <td class="py-3">${inv.ContractorName}</td>
                        <td class="py-3">RM ${fmtMoney(inv.TotalCost)}</td>
                        <td class="py-3">RM ${fmtMoney(inv.PlatformFee)}</td>
                        <td class="py-3">RM ${fmtMoney(inv.ContractorEarnings)}</td>
                        <td class="py-3">${inv.PaymentMethod}</td>
                    </tr>
                `;
                }

                renderPager();
            }

            function renderPager() {
                const pager = document.getElementById("pager");
                pager.innerHTML = "";

                const totalPages = Math.ceil(rows.length / PAGE_SIZE);

                for (let i = 1; i <= totalPages; i++) {
                    pager.innerHTML += `
                    <button onclick="window.goToRevenuePage(${i})"
                        class="mx-1 px-3 py-1 rounded-full ${i === currentPage ? "bg-yellow-400 text-black" : "bg-[#222] text-gray-300"}">
                        ${i}
                    </button>
                `;
                }
            }

            window.goToRevenuePage = (p) => renderPage(p);

            function loadRevenueReport() {
                const q = query(collection(db, "JobInvoice"), orderBy("__name__"));

                onSnapshot(q, async (invoiceSnap) => {
                rows = [];

                let totalRevenue = 0;
                let serviceRevenue = {};
                let jobCount = invoiceSnap.size;

                for (const docSnap of invoiceSnap.docs) {
                    const inv = docSnap.data();
                    const jobId = docSnap.id;

                    // get contractor name
                    let contractorName = "Unknown";

                    if (inv.ContractorID) {
                        const conRef = doc(db, "Contractor", inv.ContractorID);
                        const conSnap = await getDoc(conRef);

                        if (conSnap.exists()) {
                            const c = conSnap.data();
                            contractorName = c.FullName || c.Name || "Unknown";
                        }
                    }


                    // Calculate platform + contractor shares (keep full precision;
                    // formatting to 2dp happens at render time).
                    const totalCost = Number(inv.TotalCost) || 0;
                    const platformFee = totalCost * 0.1;
                    const contractorEarnings = totalCost - platformFee;

                    // accumulate totals
                    totalRevenue += inv.TotalCost;
                    serviceRevenue[inv.ServiceType] =
                        (serviceRevenue[inv.ServiceType] || 0) + inv.TotalCost;

                    // store in array for pagination
                    rows.push({
                        JobID: jobId,
                        ServiceType: inv.ServiceType,
                        ContractorName: contractorName,
                        TotalCost: inv.TotalCost,
                        PlatformFee: platformFee,
                        ContractorEarnings: contractorEarnings,
                        PaymentMethod: inv.PaymentMethod
                    });
                }

                // update top summary boxes
                document.getElementById("totalRevenue").textContent = fmtMoney(totalRevenue);
                document.getElementById("totalJobsCompleted").textContent = jobCount;
                document.getElementById("avgRevenue").textContent =
                    fmtMoney(jobCount > 0 ? (totalRevenue / jobCount) : 0);

                let topService = Object.entries(serviceRevenue)
                    .sort((a, b) => b[1] - a[1])[0];
                document.getElementById("topService").textContent =
                    topService ? topService[0] : "—";

                renderPage(1);
                });
            }

            loadRevenueReport();

        });
    </script>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-semibold mb-6">Reports</h1>

    <div class="flex gap-8 mb-6 border-b border-[#333] pb-2">
        <a href="RevenueReports.aspx" class="text-yellow-400 font-semibold cursor-pointer">Revenue Report
        </a>
        <a href="JobPerformance.aspx" class="text-gray-400 cursor-pointer">Job Performance Report
        </a>
        <a href="ContractorPerformance.aspx" class="text-gray-400 cursor-pointer">Contractor Performance Report
        </a>
        <a href="UserActivity.aspx" class="text-gray-400 cursor-pointer">User Activity Report
        </a>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-10">

        <!-- Total Revenue -->
        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Total Revenue</p>
            <h2 class="text-3xl font-bold text-yellow-400">RM <span id="totalRevenue">0</span></h2>
        </div>

        <!-- Total Jobs Completed -->
        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Total Jobs Completed</p>
            <h2 class="text-3xl font-bold text-green-400"><span id="totalJobsCompleted">0</span></h2>
        </div>

        <!-- Avg Revenue -->
        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Average Revenue per Job</p>
            <h2 class="text-3xl font-bold text-red-400">RM <span id="avgRevenue">0</span></h2>
        </div>

        <!-- Top Service -->
        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Top Service Type by Revenue</p>
            <h2 class="text-3xl font-bold text-yellow-400"><span id="topService">—</span></h2>
        </div>

    </div>

    <!-- Revenue Report Table -->
    <div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333]">

        <!-- Table Title + Actions -->
        <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl font-semibold">Revenue Report</h2>

            <div class="flex gap-3 items-center">
                <i data-lucide="filter" class="w-6 h-6 text-gray-400 cursor-pointer"></i>

                <div class="relative">
                    <input id="searchInput"
                        class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4 pl-10"
                        placeholder="Search (Name or ID)">
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-5 h-5 text-gray-400"></i>
                </div>
            </div>
        </div>

        <!-- Table -->
        <table class="w-full text-sm">
            <thead class="text-gray-400 border-b border-[#333]">
                <tr>
                    <th class="pb-3 text-left">Job ID</th>
                    <th class="pb-3 text-left">Service Type</th>
                    <th class="pb-3 text-left">Contractor Name</th>
                    <th class="pb-3 text-left">Total Cost (RM)</th>
                    <th class="pb-3 text-left">Platform Fee (RM)</th>
                    <th class="pb-3 text-left">Contractor Earnings (RM)</th>
                    <th class="pb-3 text-left">Payment Method</th>
                </tr>
            </thead>
            <tbody id="revenueTable"></tbody>
        </table>

        <div class="flex justify-center mt-6" id="pager"></div>

        <div class="text-right mt-4">
            <a href="#" id="exportCSV" class="text-red-400 hover:underline">Export (CSV)</a>
        </div>

    </div>

</asp:Content>


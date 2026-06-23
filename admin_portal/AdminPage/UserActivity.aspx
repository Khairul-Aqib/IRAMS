<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true"
    CodeBehind="UserActivity.aspx.cs" Inherits="AdminPage.UserActivity" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    User Activity Report
</asp:Content>


<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">

    <script type="module">
        import {
            collection,
            getDocs,
            onSnapshot
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        document.addEventListener("firebase-auth-ready", async () => {

            const PAGE_SIZE = 10;
            let rows = [];
            let currentPage = 1;

            function parseTS(v) {
                if (!v) return null;
                if (typeof v.toDate === "function") return v.toDate();
                const d = new Date(v);
                return isNaN(d.getTime()) ? null : d;
            }

            function formatDate(d) {
                if (!d) return "N/A";
                return d.toLocaleDateString();
            }

            function renderSummary(totalUsers, activeUsers30, newUsersMonth, topService) {
                document.getElementById("totalUsers").textContent = totalUsers;
                document.getElementById("activeUsers").textContent = activeUsers30;
                document.getElementById("newUsers").textContent = newUsersMonth;
                document.getElementById("topService").textContent = topService || "N/A";
            }

            function renderTable(page = 1) {
                currentPage = page;
                const tbody = document.getElementById("userTableBody");
                tbody.innerHTML = "";

                if (rows.length === 0) {
                    tbody.innerHTML = `<tr><td colspan="7" class="py-6 text-center text-gray-400">No users found</td></tr>`;
                    renderPager();
                    return;
                }

                const start = (page - 1) * PAGE_SIZE;
                const pageRows = rows.slice(start, start + PAGE_SIZE);

                for (const r of pageRows) {
                    tbody.innerHTML += `
                <tr class="border-b border-[#333]">
                    <td class="py-3">${r.Name}</td>
                    <td class="py-3">${r.Email}</td>
                    <td class="py-3">${r.Phone}</td>
                    <td class="py-3">${formatDate(r.Registered)}</td>
                    <td class="py-3">${r.TotalJobs}</td>
                    <td class="py-3">${r.MostUsedService}</td>
                    <td class="py-3">${r.Status}</td>
                </tr>`;
                }

                renderPager();
            }

            function renderPager() {
                const pager = document.getElementById("pager");
                pager.innerHTML = "";

                const totalPages = Math.ceil(rows.length / PAGE_SIZE);

                for (let p = 1; p <= totalPages; p++) {
                    pager.innerHTML += `
                    <button onclick="window.goPage(${p})"
                        class="mx-1 px-3 py-1 rounded-full ${p === currentPage ? 'bg-yellow-400 text-black' : 'bg-[#222] text-gray-300'}">
                        ${p}
                    </button>`;
                }
            }

            window.goPage = (p) => renderTable(p);

            // Export Csv
            function exportCsv() {
                if (!rows.length) return alert("No data to export");

                const headers = ["Name", "Email", "Phone", "Registered", "TotalJobs", "MostUsedService", "Status"];
                const csvRows = [headers.join(",")];

                for (const r of rows) {
                    csvRows.push([
                        r.Name,
                        r.Email,
                        r.Phone,
                        formatDate(r.Registered),
                        r.TotalJobs,
                        r.MostUsedService,
                        r.Status
                    ].map(v => `"${v}"`).join(","));
                }

                const blob = new Blob([csvRows.join("\n")], { type: "text/csv" });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                a.href = url;
                a.download = "UserActivityReport.csv";
                a.click();
                URL.revokeObjectURL(url);
            }

            document.getElementById("exportCSV").addEventListener("click", e => {
                e.preventDefault();
                exportCsv();
            });

            // Main Loading (real-time on Users, one-off for jobs)
            function loadUserReport() {
                onSnapshot(collection(db, "Users"), async (userSnap) => {
                const jobsSnap = await getDocs(collection(db, "Jobs"));

                rows = [];

                // Build a map of jobs per user
                const jobMap = {};
                jobsSnap.forEach(doc => {
                    const d = doc.data();
                    let uid = d.UserID;

                    // Handle different UserID formats
                    if (!uid) return;

                    // If it's a reference object with a path property
                    if (uid && typeof uid === "object" && uid.path) {
                        uid = uid.path.split('/').pop();
                    }
                    // If it's a string path
                    else if (typeof uid === "string" && uid.includes('/')) {
                        uid = uid.split('/').pop();
                    }
                    
                    else if (typeof uid === "string") {
                        uid = uid; 
                    } else {
                        return;
                    }

                    console.log("Processing job for UserID:", uid);

                    if (!jobMap[uid]) jobMap[uid] = [];
                    jobMap[uid].push(d);
                });

                console.log("Job Map:", jobMap);

                const now = new Date();
                let newUsersCount = 0;
                let activeUsersLast30Days = 0;
                const serviceCounter = {};

                // Calculate 30 days ago
                const thirtyDaysAgo = new Date();
                thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

                userSnap.forEach(doc => {
                    const u = doc.data();
                    const uid = doc.id;

                    // Mobile app writes camelCase `createdAt`; older admin writes
                    // used `CreatedAt`; legacy seed data used `RegistrationDate`.
                    const regDate = parseTS(u.CreatedAt || u.createdAt || u.RegistrationDate);

                    // Count new users this month
                    if (
                        regDate &&
                        regDate.getMonth() === now.getMonth() &&
                        regDate.getFullYear() === now.getFullYear()
                    ) {
                        newUsersCount++;
                    }

                    const jobs = jobMap[uid] || [];

                    // Check if user was active in last 30 days
                    let hasRecentActivity = false;
                    for (const job of jobs) {
                        const requestedTime = parseTS(job.DateRequested);
                        if (requestedTime && requestedTime >= thirtyDaysAgo) {
                            hasRecentActivity = true;
                            break;
                        }
                    }
                    if (hasRecentActivity) activeUsersLast30Days++;

                    // Find most used service for this user
                    let topService = "N/A";
                    if (jobs.length) {
                        const count = {};
                        for (const j of jobs) {
                            const service = j.ServiceType || "Unknown";
                            count[service] = (count[service] || 0) + 1;
                            serviceCounter[service] = (serviceCounter[service] || 0) + 1;
                        }
                        topService = Object.keys(count).reduce((a, b) => count[a] > count[b] ? a : b);
                    }

                    rows.push({
                        UserID: uid,
                        // Mobile-app signups write camelCase; older admin/seed data
                        // used PascalCase. Read camelCase first so new accounts
                        // populate correctly.
                        Name:  u.fullName || u.FullName || u.Name || "Unknown",
                        Email: u.email || u.Email || "",
                        Phone: u.phone || u.PhoneNumber || u.Phone || "",
                        Registered: regDate,
                        TotalJobs: jobs.length,
                        MostUsedService: topService,
                        Status: u.accountStatus || u.Status || u.AccountStatus || "Active"
                    });
                });

                // Find most popular service globally
                let topGlobalService = "N/A";
                if (Object.keys(serviceCounter).length) {
                    topGlobalService = Object.keys(serviceCounter)
                        .reduce((a, b) => serviceCounter[a] > serviceCounter[b] ? a : b);
                }

                console.log("Total Users:", userSnap.size);
                console.log("Active Users (Last 30 Days):", activeUsersLast30Days);
                console.log("New Users This Month:", newUsersCount);
                console.log("Top Service:", topGlobalService);

                renderSummary(userSnap.size, activeUsersLast30Days, newUsersCount, topGlobalService);
                renderTable(1);
                }, (err) => {
                    console.error("User load error:", err);
                });
            }

            loadUserReport();
        });

    </script>

</asp:Content>



<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-semibold mb-6">Reports</h1>

    <div class="flex gap-8 mb-6 border-b border-[#333] pb-2">
        <a href="RevenueReports.aspx" class="text-gray-400">Revenue Report</a>
        <a href="JobPerformance.aspx" class="text-gray-400">Job Performance Report</a>
        <a href="ContractorPerformance.aspx" class="text-gray-400">Contractor Performance Report</a>
        <a href="UserActivity.aspx" class="text-yellow-400 font-semibold">User Activity Report</a>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Total Users</p>
            <h2 class="text-3xl font-bold text-yellow-400"><span id="totalUsers">0</span></h2>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Active Users (Last 30 Days)</p>
            <h2 class="text-3xl font-bold text-green-400"><span id="activeUsers">0</span></h2>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">New Users (This Month)</p>
            <h2 class="text-3xl font-bold text-red-400"><span id="newUsers">0</span></h2>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333]">
            <p class="text-sm text-gray-400">Most Used Service Type</p>
            <h2 class="text-3xl font-bold text-yellow-400"><span id="topService">N/A</span></h2>
        </div>

    </div>

    <!-- User Activity Tables -->
    <div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333]">

        <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl font-semibold">User Activity Report</h2>

            <div class="flex gap-3 items-center">
                <i data-lucide="filter" class="w-6 h-6 text-gray-400"></i>

                <div class="relative">
                    <input class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4 pl-10"
                        placeholder="Search (Name, Email or ID)">
                    <i data-lucide="search" class="absolute left-3 top-2.5 w-5 h-5 text-gray-400"></i>
                </div>
            </div>
        </div>

        <table class="w-full text-sm">
            <thead class="text-gray-400 border-b border-[#333]">
                <tr>
                    <th class="pb-3 text-left">Name</th>
                    <th class="pb-3 text-left">Email Address</th>
                    <th class="pb-3 text-left">Phone</th>
                    <th class="pb-3 text-left">Registration Date</th>
                    <th class="pb-3 text-left">Total Jobs Requested</th>
                    <th class="pb-3 text-left">Most Used Service</th>
                    <th class="pb-3 text-left">Status</th>
                </tr>
            </thead>

            <tbody id="userTableBody"></tbody>
        </table>

        <div id="pager" class="flex justify-center w-full mt-6"></div>
        <div class="text-right mt-4">
            <a href="#" id="exportCSV" class="text-red-400 hover:underline">Export (CSV)</a>
        </div>

    </div>

</asp:Content>

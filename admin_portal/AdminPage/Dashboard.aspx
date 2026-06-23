<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true"
    CodeBehind="Dashboard.aspx.cs" Inherits="AdminPage.WebForm1" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Admin Dashboard
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
    <script type="module">

        import {
            collection,
            getCountFromServer,
            getDocs,
            onSnapshot,
            doc,
            getDoc,
            query,
            where,
            limit,
            orderBy
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        document.addEventListener("firebase-auth-ready", async () => {

            async function loadDashboardCounts() {
                const users = await getCountFromServer(collection(db, "Users"));
                const contractors = await getCountFromServer(collection(db, "Contractor"));
                const jobs = await getCountFromServer(collection(db, "Jobs"));
                const services = await getCountFromServer(collection(db, "Services"));

                document.getElementById("countUsers").textContent = users.data().count;
                document.getElementById("countContractors").textContent = contractors.data().count;
                document.getElementById("countJobs").textContent = jobs.data().count;
                document.getElementById("countServices").textContent = services.data().count;
            }

            // Active Jobs (real-time)
            function loadActiveJobs() {
                const table = document.getElementById("activeJobsTable");
                table.innerHTML = "";

                // Sorted by most recent request first, capped at 5 for the dashboard.
                // Firestore needs a composite index on (Status, DateRequested) — if
                // the query throws, the browser console will print a one-click link
                // to create it.
                const q = query(
                    collection(db, "Jobs"),
                    where("Status", "in", ["Pending", "Accepted", "In Progress", "Arrived"]),
                    orderBy("DateRequested", "desc"),
                    limit(5)
                );

                onSnapshot(q, async (snap) => {
                    table.innerHTML = "";

                    if (snap.empty) {
                        table.innerHTML = '<tr><td colspan="5" class="py-6 text-center text-gray-400">No active jobs</td></tr>';
                        return;
                    }

                    for (const jobDoc of snap.docs) {
                        const j = jobDoc.data();

                        let contractorName = "Not Assigned";
                        if (j.ContractorAssigned) {
                            try {
                                const csnap = await getDoc(j.ContractorAssigned);
                                if (csnap.exists()) {
                                    const c = csnap.data();
                                    contractorName = c.FullName || c.CompanyName || c.ContractorID || "Unknown";
                                }
                            } catch (err) {
                                console.warn("Error fetching contractor:", err);
                            }
                        }

                        let badgeClass = "px-3 py-1 rounded-full text-xs ";
                        const status = (j.Status || "").toLowerCase();
                        if (status === "accepted") {
                            badgeClass += "bg-green-600 text-white";
                        } else if (status === "pending") {
                            badgeClass += "bg-yellow-600 text-white";
                        } else if (status === "on the way" || status === "in progress") {
                            badgeClass += "bg-blue-600 text-white";
                        } else if (status === "cancelled") {
                            badgeClass += "bg-red-600 text-white";
                        } else {
                            badgeClass += "bg-gray-600 text-white";
                        }

                        table.innerHTML += `
                <tr class="border-b border-[#333] hover:bg-[#262626]">
                    <td class="py-3">${j.JobID || jobDoc.id}</td>
                    <td class="py-3">${j.ServiceType || "N/A"}</td>
                    <td class="py-3">${j.UserLocation || "N/A"}</td>
                    <td class="py-3"><span class="${badgeClass}">${j.Status || "Unknown"}</span></td>
                    <td class="py-3">${contractorName}</td>
                </tr>`;
                    }
                }, (error) => {
                    console.error("Error loading active jobs:", error);
                    table.innerHTML = '<tr><td colspan="5" class="py-6 text-center text-red-400">Error loading active jobs</td></tr>';
                });
            }

            // Recent Job Invoices (real-time)
            function loadRecentInvoices() {
                const table = document.getElementById("recentInvoicesTable");
                table.innerHTML = "";

                const q = query(
                    collection(db, "JobInvoice"),
                    orderBy("RequestedTime", "desc"),
                    limit(5)
                );

                onSnapshot(q, async (snap) => {
                    table.innerHTML = "";

                    if (snap.empty) {
                        table.innerHTML = '<tr><td colspan="7" class="py-6 text-center text-gray-400">No recent invoices</td></tr>';
                        return;
                    }

                    for (const invDoc of snap.docs) {
                        const d = invDoc.data();
                        const jobId = d.JobID || invDoc.id;

                        // Pull userName / userLocation from the linked Jobs doc
                        // (the invoice doesn't reliably carry these), with fallbacks
                        // for both PascalCase (admin-written) and camelCase (mobile-written).
                        let jobUserName = "";
                        let jobUserLocation = "";
                        let jobUserId = null;
                        try {
                            const jobSnap = await getDoc(doc(db, "Jobs", jobId));
                            if (jobSnap.exists()) {
                                const j = jobSnap.data();
                                jobUserName = j.userName || j.UserName || "";
                                jobUserLocation = j.userLocation || j.UserLocation || "";
                                jobUserId = j.UserID;
                            }
                        } catch (e) {
                            console.warn("Job lookup failed for:", jobId, e);
                        }

                        // User doc lookup — used only if the Job doc didn't carry a
                        // userName, e.g. legacy data. UserID can be a DocumentReference,
                        // a path string, or a bare doc id.
                        let userName = jobUserName || "Unknown";
                        if (!jobUserName) {
                            try {
                                const uidVal = jobUserId || d.UserID;
                                if (uidVal) {
                                    let userSnap = null;
                                    if (typeof uidVal === "object" && uidVal.path) {
                                        userSnap = await getDoc(uidVal);
                                    } else if (typeof uidVal === "string") {
                                        let uid = uidVal;
                                        if (uid.includes('/')) uid = uid.split('/').pop();
                                        userSnap = await getDoc(doc(db, "Users", uid));
                                    }
                                    if (userSnap && userSnap.exists()) {
                                        const u = userSnap.data();
                                        userName = u.fullName || u.FullName || u.Name || "Unknown";
                                    }
                                }
                            } catch (e) {
                                console.warn("User lookup failed for:", jobUserId || d.UserID, e);
                            }
                        }

                        const userLocation = jobUserLocation || d.UserLocation || "N/A";

                        // Contractor Lookup
                        let contractorName = "Unknown";
                        try {
                            if (d.ContractorID) {
                                const cSnap = await getDoc(doc(db, "Contractor", d.ContractorID));
                                if (cSnap.exists()) {
                                    const c = cSnap.data();
                                    contractorName = c.FullName || c.CompanyName || d.ContractorID;
                                }
                            }
                        } catch (e) {
                            console.warn("Contractor lookup failed for:", d.ContractorID, e);
                        }

                        // Format the requested time
                        let formattedTime = "N/A";
                        if (d.RequestedTime) {
                            try {
                                const date = d.RequestedTime.toDate ? d.RequestedTime.toDate() : new Date(d.RequestedTime.seconds * 1000);
                                formattedTime = date.toLocaleDateString('en-MY', {
                                    month: 'short',
                                    day: 'numeric',
                                    hour: '2-digit',
                                    minute: '2-digit'
                                });
                            } catch (e) {
                                console.warn("Error formatting date:", e);
                            }
                        }

                        table.innerHTML += `
                <tr class="border-b border-[#333] hover:bg-[#262626]">
                    <td class="py-3">${jobId}</td>
                    <td class="py-3">${userName}</td>
                    <td class="py-3">${userLocation}</td>
                    <td class="py-3">${d.ServiceType || "N/A"}</td>
                    <td class="py-3">RM ${d.TotalCost || "0"}</td>
                    <td class="py-3">${d.PaymentMethod || "N/A"}</td>
                    <td class="py-3">${contractorName}</td>
                </tr>`;
                    }
                }, (error) => {
                    console.error("Error loading recent invoices:", error);
                    table.innerHTML = '<tr><td colspan="7" class="py-6 text-center text-red-400">Error loading invoices</td></tr>';
                });
            }

            // Load all dashboard data
            try {
                await loadDashboardCounts();
                loadActiveJobs();
                loadRecentInvoices();
            } catch (error) {
                console.error("Dashboard loading error:", error);
            }
        });
</script>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-2xl font-bold mb-6">Admin Dashboard</h1>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-10">

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333] flex items-center gap-4">
            <div class="p-3 rounded-lg bg-blue-600/20">
                <i data-lucide="users" class="w-8 h-8 text-blue-400"></i>
            </div>
            <div>
                <p class="text-sm text-gray-400">Total Users</p>
                <h2 class="text-2xl font-bold"><span id="countUsers">0</span></h2>
            </div>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333] flex items-center gap-4">
            <div class="p-3 rounded-lg bg-yellow-500/20">
                <i data-lucide="badge-check" class="w-8 h-8 text-yellow-400"></i>
            </div>
            <div>
                <p class="text-sm text-gray-400">Total Contractors</p>
                <h2 class="text-2xl font-bold"><span id="countContractors">0</span></h2>
            </div>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333] flex items-center gap-4">
            <div class="p-3 rounded-lg bg-green-500/20">
                <i data-lucide="check-circle" class="w-8 h-8 text-green-400"></i>
            </div>
            <div>
                <p class="text-sm text-gray-400">Jobs</p>
                <h2 class="text-2xl font-bold"><span id="countJobs">0</span></h2>
            </div>
        </div>

        <div class="bg-[#1f1f1f] p-5 rounded-xl border border-[#333] flex items-center gap-4">
            <div class="p-3 rounded-lg bg-purple-500/20">
                <i data-lucide="layers" class="w-8 h-8 text-purple-400"></i>
            </div>
            <div>
                <p class="text-sm text-gray-400">Services</p>
                <h2 class="text-2xl font-bold"><span id="countServices">0</span></h2>
            </div>
        </div>

    </div>

    <!-- Active Jobs -->
    <div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333] mb-10">
        <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold">Active Jobs List</h2>
            <a href="ActiveJobList.aspx"
               title="View all active jobs"
               class="text-gray-400 hover:text-yellow-400">
                <i data-lucide="external-link" class="w-5 h-5"></i>
            </a>
        </div>
        <table class="w-full text-sm">
            <thead class="text-gray-400 border-b border-[#333]">
                <tr>
                    <th class="pb-3 text-left">Job ID</th>
                    <th class="pb-3 text-left">Service Type</th>
                    <th class="pb-3 text-left">User Location</th>
                    <th class="pb-3 text-left">Status</th>
                    <th class="pb-3 text-left">Contractor</th>
                </tr>
            </thead>
            <tbody id="activeJobsTable"></tbody>
        </table>
    </div>

    <!-- Recent Invoices -->
    <div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333] mb-10">
        <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold">Recent Job Invoices</h2>
            <a href="RecentJobList.aspx"
               title="View all recent invoices"
               class="text-gray-400 hover:text-yellow-400">
                <i data-lucide="external-link" class="w-5 h-5"></i>
            </a>
        </div>
        <table class="w-full text-sm">
            <thead class="text-gray-400 border-b border-[#333]">
                <tr>
                    <th class="pb-3 text-left">Job ID</th>
                    <th class="pb-3 text-left">User</th>
                    <th class="pb-3 text-left">User Location</th>
                    <th class="pb-3 text-left">Service Type</th>
                    <th class="pb-3 text-left">Total Cost (RM)</th>
                    <th class="pb-3 text-left">Payment Method</th>
                    <th class="pb-3 text-left">Contractor</th>
                </tr>
            </thead>
            <tbody id="recentInvoicesTable"></tbody>
        </table>
    </div>

</asp:Content>

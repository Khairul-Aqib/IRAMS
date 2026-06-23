<%@ Page Title="Jobs Management" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true" CodeBehind="Jobs.aspx.cs" Inherits="AdminPage.Jobs" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Jobs Management
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
   
    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Jobs Management</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">
        <div class="flex justify-between mb-4">
            <div class="flex gap-4">
                <!-- Search Bar -->
                <input type="text" placeholder="Search Jobs" class="bg-[#0d0d0d] text-white px-4 py-2 rounded-lg" id="searchJobs">
                <!-- Sort By -->
                <select class="bg-[#0d0d0d] text-white px-4 py-2 rounded-lg custom-dropdown" id="sortJobs">
                    <option value="date-desc">Request Date (Newest First)</option>
                    <option value="date-asc">Request Date (Oldest First)</option>
                    <option value="status">Status</option>
                </select>
            </div>
        </div>

        <!-- Job Table -->
        <table class="min-w-full text-sm">
            <thead>
                <tr class="bg-[#262626] text-gray-300">
                    <th class="py-3 px-4 text-left">Job ID</th>
                    <th class="py-3 px-4 text-left">Service Type</th>
                    <th class="py-3 px-4 text-left">User Full Name</th>
                    <th class="py-3 px-4 text-left">User Location</th>
                    <th class="py-3 px-4 text-left">Contractor Assigned</th>
                    <th class="py-3 px-4 text-left">Request Date</th>
                    <th class="py-3 px-4 text-left">Status</th>
                    <th class="py-3 px-4 text-left">Total Cost</th>
                    <th class="py-3 px-4 text-left">Actions</th>
                </tr>
            </thead>
            <tbody id="jobsTableBody">
                <tr>
                    <td colspan="9" class="py-4 px-4 text-center text-gray-400">Loading jobs...</td>
                </tr>
            </tbody>
        </table>

        <!-- Pagination Controls -->
        <div id="paginationControls" class="flex items-center justify-between mt-4 text-sm text-gray-300">
            <div id="pageInfo"></div>
            <div class="flex gap-2" id="pageButtons"></div>
        </div>
    </div>

    <style>
        /* Custom dropdown arrow styling */
        select.custom-dropdown {
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%239ca3af'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 0.75rem center;
            background-size: 1rem;
            padding-right: 2.5rem;
            appearance: none;
            -webkit-appearance: none;
            -moz-appearance: none;
        }
    </style>

    <script type="module">
        import {
            collection,
            getDocs,
            onSnapshot,
            doc,
            getDoc,
            query,
            orderBy,
            limit
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        let allJobs = []; // Store all jobs for filtering/sorting
        let filteredJobs = []; // Current filtered/sorted view
        let currentPage = 1;
        const jobsPerPage = 10;

        document.addEventListener("firebase-auth-ready", () => {
            loadJobs();
            setupSearchAndSort();
        });

        // Caches to avoid re-fetching the same user/contractor
        const userCache = {};
        const contractorCache = {};

        function loadJobs() {
            const tbody = document.getElementById("jobsTableBody");
            tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-gray-400'>Loading jobs...</td></tr>";

            // Only fetch the 100 most recent jobs, already sorted by Firestore
            const jobsQuery = query(
                collection(window.db, "Jobs"),
                orderBy("DateRequested", "desc"),
                limit(100)
            );

            onSnapshot(jobsQuery, async (snapshot) => {
                try {
                    allJobs = snapshot.docs.map(d => ({ id: d.id, ...d.data() }));

                    // Resolve all user + contractor names concurrently with caching
                    await Promise.all(allJobs.map(async (job) => {
                        const [userName, contractorName] = await Promise.all([
                            job.UserID ? fetchUserFullName(job.UserID) : Promise.resolve('N/A'),
                            job.ContractorAssigned ? fetchContractorFullName(job.ContractorAssigned) : Promise.resolve('Not Assigned')
                        ]);
                        job.userFullName = userName;
                        job.contractorFullName = contractorName;
                    }));

                    // Already sorted newest-first by the query, but keep client sort
                    // in sync so the sort dropdown default matches
                    allJobs.sort((a, b) => {
                        const dateA = a.DateRequested ? new Date(a.DateRequested.seconds * 1000) : new Date(0);
                        const dateB = b.DateRequested ? new Date(b.DateRequested.seconds * 1000) : new Date(0);
                        return dateB - dateA;
                    });

                    filteredJobs = [...allJobs];
                    currentPage = 1;
                    renderPage();
                } catch (error) {
                    console.error("Error processing jobs:", error);
                    tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-red-400'>Error loading jobs. Please try again.</td></tr>";
                }
            }, (error) => {
                console.error("Error loading jobs:", error);
                tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-red-400'>Error loading jobs. Please try again.</td></tr>";
            });
        }

        function renderPage() {
            const totalPages = Math.ceil(filteredJobs.length / jobsPerPage);
            if (currentPage > totalPages && totalPages > 0) currentPage = totalPages;

            const start = (currentPage - 1) * jobsPerPage;
            const end = start + jobsPerPage;
            const pageJobs = filteredJobs.slice(start, end);

            renderJobs(pageJobs);
            renderPagination(totalPages);
        }

        function renderPagination(totalPages) {
            const pageInfo = document.getElementById("pageInfo");
            const pageButtons = document.getElementById("pageButtons");

            if (filteredJobs.length === 0) {
                pageInfo.textContent = "";
                pageButtons.innerHTML = "";
                return;
            }

            const start = (currentPage - 1) * jobsPerPage + 1;
            const end = Math.min(currentPage * jobsPerPage, filteredJobs.length);
            pageInfo.textContent = `Showing ${start}-${end} of ${filteredJobs.length} jobs`;

            pageButtons.innerHTML = "";

            // Previous button
            const prevBtn = document.createElement("button");
            prevBtn.textContent = "Previous";
            prevBtn.className = `px-3 py-1 rounded ${currentPage === 1 ? 'bg-[#333] text-gray-500 cursor-not-allowed' : 'bg-[#333] text-white hover:bg-[#444] cursor-pointer'}`;
            prevBtn.disabled = currentPage === 1;
            prevBtn.addEventListener("click", () => { if (currentPage > 1) { currentPage--; renderPage(); } });
            pageButtons.appendChild(prevBtn);

            // Page number buttons
            const maxVisible = 5;
            let startPage = Math.max(1, currentPage - Math.floor(maxVisible / 2));
            let endPage = Math.min(totalPages, startPage + maxVisible - 1);
            if (endPage - startPage < maxVisible - 1) startPage = Math.max(1, endPage - maxVisible + 1);

            if (startPage > 1) {
                pageButtons.appendChild(createPageBtn(1));
                if (startPage > 2) {
                    const dots = document.createElement("span");
                    dots.textContent = "...";
                    dots.className = "px-2 py-1 text-gray-400";
                    pageButtons.appendChild(dots);
                }
            }

            for (let i = startPage; i <= endPage; i++) {
                pageButtons.appendChild(createPageBtn(i));
            }

            if (endPage < totalPages) {
                if (endPage < totalPages - 1) {
                    const dots = document.createElement("span");
                    dots.textContent = "...";
                    dots.className = "px-2 py-1 text-gray-400";
                    pageButtons.appendChild(dots);
                }
                pageButtons.appendChild(createPageBtn(totalPages));
            }

            // Next button
            const nextBtn = document.createElement("button");
            nextBtn.textContent = "Next";
            nextBtn.className = `px-3 py-1 rounded ${currentPage === totalPages ? 'bg-[#333] text-gray-500 cursor-not-allowed' : 'bg-[#333] text-white hover:bg-[#444] cursor-pointer'}`;
            nextBtn.disabled = currentPage === totalPages;
            nextBtn.addEventListener("click", () => { if (currentPage < totalPages) { currentPage++; renderPage(); } });
            pageButtons.appendChild(nextBtn);
        }

        function createPageBtn(page) {
            const btn = document.createElement("button");
            btn.textContent = page;
            btn.className = `px-3 py-1 rounded cursor-pointer ${page === currentPage ? 'bg-yellow-600 text-white' : 'bg-[#333] text-white hover:bg-[#444]'}`;
            btn.addEventListener("click", () => { currentPage = page; renderPage(); });
            return btn;
        }

        function renderJobs(jobs) {
            const tbody = document.getElementById("jobsTableBody");
            tbody.innerHTML = "";

            if (jobs.length === 0) {
                tbody.innerHTML = "<tr><td colspan='9' class='py-4 px-4 text-center text-gray-400'>No jobs available.</td></tr>";
                return;
            }

            jobs.forEach(job => {
                const tr = document.createElement("tr");
                tr.className = "hover:bg-[#262626] border-t border-[#333]";

                // Determine status color
                let statusClass = "bg-gray-600";
                const status = (job.Status || "").toLowerCase();
                if (status === "completed") {
                    statusClass = "bg-green-600";
                } else if (status === "pending") {
                    statusClass = "bg-yellow-600";
                } else if (status === "in progress" || status === "on the way") {
                    statusClass = "bg-blue-600";
                } else if (status === "cancelled") {
                    statusClass = "bg-red-600";
                }

                // Format the request date
                let formattedDate = '-';
                if (job.DateRequested) {
                    const date = job.DateRequested.toDate ? job.DateRequested.toDate() : new Date(job.DateRequested.seconds * 1000);
                    formattedDate = date.toLocaleDateString('en-MY', {
                        year: 'numeric',
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                }

                tr.innerHTML = `
                    <td class="py-3 px-4">${job.JobID || job.id}</td>
                    <td class="py-3 px-4">${job.ServiceType || '-'}</td>
                    <td class="py-3 px-4">${job.userFullName || 'N/A'}</td>
                    <td class="py-3 px-4">${job.UserLocation || '-'}</td>
                    <td class="py-3 px-4">${job.contractorFullName || 'Not Assigned'}</td>
                    <td class="py-3 px-4">${formattedDate}</td>
                    <td class="py-3 px-4">
                        <span class="px-3 py-1 rounded text-xs ${statusClass} text-white whitespace-nowrap">
                            ${job.Status || 'Unknown'}
                        </span>
                    </td>
                    <td class="py-3 px-4">RM ${(parseFloat(job.TotalCost) || 0).toFixed(2)}</td>
                    <td class="py-3 px-4">
                        <a href="JobDetails.aspx?id=${job.id}" class="text-blue-400 hover:underline">View Details</a>
                    </td>
                `;
                tbody.appendChild(tr);
            });
        }

        function extractId(ref) {
            if (ref && typeof ref === 'object' && ref.path) return ref.path.split('/').pop();
            if (typeof ref === 'string' && ref.includes('/')) return ref.split('/').pop();
            return typeof ref === 'string' ? ref : String(ref);
        }

        async function fetchUserFullName(userID) {
            try {
                const userId = extractId(userID);
                if (userCache[userId]) return userCache[userId];

                const userSnap = await getDoc(doc(window.db, "Users", userId));
                let fullName = 'N/A';
                if (userSnap.exists()) {
                    const u = userSnap.data();
                    fullName = u.fullName || u.FullName || u.Name || 'N/A';
                }
                userCache[userId] = fullName;
                return fullName;
            } catch (error) {
                console.error("Error fetching user:", error);
                return 'N/A';
            }
        }

        async function fetchContractorFullName(contractorAssigned) {
            try {
                const contractorId = extractId(contractorAssigned);
                if (contractorCache[contractorId]) return contractorCache[contractorId];

                const contractorSnap = await getDoc(doc(window.db, "Contractor", contractorId));
                const fullName = contractorSnap.exists() ? (contractorSnap.data().FullName || 'N/A') : 'Not Assigned';
                contractorCache[contractorId] = fullName;
                return fullName;
            } catch (error) {
                console.error("Error fetching contractor:", error);
                return 'N/A';
            }
        }

        function setupSearchAndSort() {
            const searchInput = document.getElementById("searchJobs");
            const sortSelect = document.getElementById("sortJobs");

            // Search functionality
            searchInput.addEventListener("input", (e) => {
                const searchTerm = e.target.value.toLowerCase();
                filteredJobs = allJobs.filter(job => {
                    return (
                        (job.JobID || '').toLowerCase().includes(searchTerm) ||
                        (job.ServiceType || '').toLowerCase().includes(searchTerm) ||
                        (job.userFullName || '').toLowerCase().includes(searchTerm) ||
                        (job.contractorFullName || '').toLowerCase().includes(searchTerm) ||
                        (job.UserLocation || '').toLowerCase().includes(searchTerm) ||
                        (job.Status || '').toLowerCase().includes(searchTerm)
                    );
                });
                currentPage = 1;
                renderPage();
            });

            // Sort functionality
            sortSelect.addEventListener("change", (e) => {
                const sortType = e.target.value;

                const sortFn = {
                    'date-asc': (a, b) => {
                        const dateA = a.DateRequested ? new Date(a.DateRequested.seconds * 1000) : new Date(0);
                        const dateB = b.DateRequested ? new Date(b.DateRequested.seconds * 1000) : new Date(0);
                        return dateA - dateB;
                    },
                    'date-desc': (a, b) => {
                        const dateA = a.DateRequested ? new Date(a.DateRequested.seconds * 1000) : new Date(0);
                        const dateB = b.DateRequested ? new Date(b.DateRequested.seconds * 1000) : new Date(0);
                        return dateB - dateA;
                    },
                    'status': (a, b) => (a.Status || '').localeCompare(b.Status || '')
                };

                if (sortFn[sortType]) {
                    allJobs.sort(sortFn[sortType]);
                    filteredJobs = [...allJobs];
                    // Re-apply search filter if active
                    const searchTerm = searchInput.value.toLowerCase();
                    if (searchTerm) {
                        filteredJobs = allJobs.filter(job => {
                            return (
                                (job.JobID || '').toLowerCase().includes(searchTerm) ||
                                (job.ServiceType || '').toLowerCase().includes(searchTerm) ||
                                (job.userFullName || '').toLowerCase().includes(searchTerm) ||
                                (job.contractorFullName || '').toLowerCase().includes(searchTerm) ||
                                (job.UserLocation || '').toLowerCase().includes(searchTerm) ||
                                (job.Status || '').toLowerCase().includes(searchTerm)
                            );
                        });
                    }
                }

                currentPage = 1;
                renderPage();
            });
        }
    </script>
</asp:Content>
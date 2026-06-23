<%@ Page Title="Assign Contractor" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true" CodeBehind="AssignContractor.aspx.cs" Inherits="AdminPage.AssignContractor" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Assign Contractor
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Jobs Management &gt; Assign Contractor</h1>

    <!-- Job Info -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8 max-w-4xl">
        <h3 class="text-xl font-semibold mb-4">Job Overview</h3>
        <p><strong>Job ID:</strong> <span id="lblJobID"></span></p>
        <p><strong>Service Type:</strong> <span id="lblServiceType"></span></p>
        <p><strong>User Location:</strong> <span id="lblUserLocation"></span></p>
        <p><strong>Date Requested:</strong> <span id="lblDateRequested"></span></p>
        <p><strong>Status:</strong> <span id="lblStatus"></span></p>
    </div>

    <!-- Available Contractors -->
    <h3 class="text-xl font-semibold mb-4 mt-8">Available Contractor List</h3>
    <table class="min-w-full text-sm">
        <thead>
            <tr class="bg-[#262626] text-gray-300">
                <th class="py-3 px-4">Contractor Name</th>
                <th class="py-3 px-4">Service Type</th>
                <th class="py-3 px-4">Location</th>
                <th class="py-3 px-4">Availability</th>
                <th class="py-3 px-4">Rating</th>
                <th class="py-3 px-4">Distance</th>
                <th class="py-3 px-4">Action</th>
            </tr>
        </thead>
        <tbody id="contractorsTableBody">
        </tbody>
    </table>

    <script type="module">
        import { collection, getDocs, onSnapshot, doc, getDoc, updateDoc } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        const jobId = new URLSearchParams(window.location.search).get("jobID");

        async function loadJobDetails() {
            const jobRef = doc(db, "Jobs", jobId);
            const jobSnap = await getDoc(jobRef);
            const jobData = jobSnap.data();

            document.getElementById("lblJobID").textContent = jobData.JobID;
            document.getElementById("lblServiceType").textContent = jobData.ServiceType;
            document.getElementById("lblUserLocation").textContent = jobData.UserLocation;
            document.getElementById("lblDateRequested").textContent = jobData.DateRequested.toDate().toLocaleString();
            document.getElementById("lblStatus").textContent = jobData.Status;
        }

        function loadAvailableContractors() {
            onSnapshot(collection(db, "Contractor"), (snapshot) => {
                const contractors = [];
                snapshot.forEach(doc => {
                    const contractorData = doc.data();
                    if (contractorData.Status === "Available") {
                        contractors.push({ id: doc.id, ...contractorData });
                    }
                });
                renderContractors(contractors);
            });
        }

        function renderContractors(contractors) {
            const tbody = document.getElementById("contractorsTableBody");
            tbody.innerHTML = "";

            contractors.forEach(contractor => {
                const tr = document.createElement("tr");
                tr.className = "hover:bg-[#262626]";
                tr.innerHTML = `
            <td class="py-3 px-4">${contractor.FullName}</td>
            <td class="py-3 px-4">${contractor.ServiceTypes.join(', ')}</td>
            <td class="py-3 px-4">${contractor.Location}</td>
            <td class="py-3 px-4">${contractor.Status}</td>
            <td class="py-3 px-4">${contractor.Rating || 'N/A'}</td>
            <td class="py-3 px-4">${contractor.Distance || 'N/A'}</td>
            <td class="py-3 px-4">
                <button class="bg-green-500 text-white px-4 py-2 rounded" onclick="assignContractor('${contractor.id}')">Assign</button>
            </td>
        `;
                tbody.appendChild(tr);
            });
        }

        async function assignContractor(contractorId) {
            const confirmation = confirm("Are you sure you want to assign this contractor to the job?");
            if (confirmation) {
                const jobRef = doc(db, "Jobs", jobId);
                const contractorRef = doc(db, "Contractor", contractorId);

                // Update job with assigned contractor
                await updateDoc(jobRef, {
                    ContractorAssigned: contractorRef,
                    Status: "Accepted"
                });

                // Update contractor status to "Unavailable"
                await updateDoc(contractorRef, {
                    Status: "Unavailable",
                    isAvailable: false
                });

                alert("Contractor assigned successfully!");
            }
        }

        document.addEventListener("firebase-auth-ready", async () => {
            await loadJobDetails();
            loadAvailableContractors();
        });
    </script>
</asp:Content>

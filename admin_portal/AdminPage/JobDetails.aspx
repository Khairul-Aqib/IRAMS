<%@ Page Title="View Job Details" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true" CodeBehind="JobDetails.aspx.cs" Inherits="AdminPage.JobDetails" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    View Job Details
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">
    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Job Management &gt; View Job Details</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8">
        <!-- Job Overview -->
        <h3 class="text-xl font-semibold mb-4">Job Overview</h3>
        <p><strong>Job ID:</strong> <span id="lblJobID"></span></p>
        <p><strong>Service Type:</strong> <span id="lblServiceType"></span></p>
        <p><strong>User Location:</strong> <span id="lblUserLocation"></span></p>
        <p><strong>Date Requested:</strong> <span id="lblDateRequested"></span></p>
        <p><strong>Status:</strong> <span id="lblStatus"></span></p>
        
        <!-- Contractor Details -->
        <h3 class="text-xl font-semibold mt-8 mb-4">Contractor Details</h3>
        <p><strong>Contractor Name:</strong> <span id="lblContractorName">N/A</span></p>
        <p><strong>Location:</strong> <span id="lblContractorLocation">N/A</span></p>
        <p><strong>Phone Number:</strong> <span id="lblContractorPhone">N/A</span></p>
        <p><strong>Rating:</strong> <span id="lblContractorRating">N/A</span></p>
    </div>

    <script type="module">
        import { doc, getDoc } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        // Get jobID from the URL
        const jobId = new URLSearchParams(window.location.search).get("id");

        if (!jobId) {
            console.error("No job ID provided in URL");
        }

        // Fetch job details
        document.addEventListener("firebase-auth-ready", async () => {
            await loadJobDetails();
        });

        async function loadJobDetails() {
            try {
                console.log("Fetching job details for Job ID:", jobId);
                const jobRef = doc(db, "Jobs", jobId);
                const jobSnap = await getDoc(jobRef);

                if (!jobSnap.exists()) {
                    console.error("Job not found for Job ID:", jobId);
                    return;
                }

                const jobData = jobSnap.data();
                console.log("Job Data:", jobData);

                // Display job details
                document.getElementById("lblJobID").textContent = jobData.JobID || 'N/A';
                document.getElementById("lblServiceType").textContent = jobData.ServiceType || 'N/A';
                document.getElementById("lblUserLocation").textContent = jobData.UserLocation || 'N/A';
                document.getElementById("lblDateRequested").textContent = jobData.DateRequested?.toDate().toLocaleString() || 'N/A';
                document.getElementById("lblStatus").textContent = jobData.Status || 'N/A';

                // Rating lives on the job, not the contractor — set it independently
                const rating = jobData.UserRating ?? jobData.userRating ?? jobData.Rating ?? jobData.rating;
                const ratingEl = document.getElementById("lblContractorRating");
                if (rating != null && rating !== '') {
                    ratingEl.innerHTML = `${rating} <i data-lucide="star" class="inline-block w-4 h-4 text-yellow-400 fill-yellow-400" style="vertical-align: -2px;"></i>`;
                    if (window.lucide) lucide.createIcons();
                } else {
                    ratingEl.textContent = 'N/A';
                }

                // Check if ContractorAssigned exists
                if (jobData.ContractorAssigned) {
                    console.log("ContractorAssigned:", jobData.ContractorAssigned);

                    // The ContractorAssigned is a DocumentReference
                    const contractorSnap = await getDoc(jobData.ContractorAssigned);

                    if (contractorSnap.exists()) {
                        const contractorData = contractorSnap.data();
                        console.log("Contractor Data:", contractorData);

                        // Display contractor details
                        document.getElementById("lblContractorName").textContent = contractorData.FullName || 'N/A';
                        document.getElementById("lblContractorLocation").textContent = contractorData.CompanyName || 'N/A';
                        document.getElementById("lblContractorPhone").textContent = contractorData.PhoneNumber || 'N/A';
                    } else {
                        console.error("Contractor document not found");
                        setContractorFieldsToNA();
                    }
                } else {
                    console.log("No contractor assigned to this job");
                    setContractorFieldsToNA();
                }
            } catch (error) {
                console.error("Error loading job details:", error);
                setContractorFieldsToNA();
            }
        }

        // Helper function to set contractor fields to N/A (rating is set from the job, not here)
        function setContractorFieldsToNA() {
            document.getElementById("lblContractorName").textContent = 'N/A';
            document.getElementById("lblContractorLocation").textContent = 'N/A';
            document.getElementById("lblContractorPhone").textContent = 'N/A';
        }

    </script>
</asp:Content>

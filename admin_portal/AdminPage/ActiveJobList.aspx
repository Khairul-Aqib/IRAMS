<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true" CodeBehind="ActiveJobList.aspx.cs" Inherits="AdminPage.ActiveJobList" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Current Active Jobs List
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
<script type="module">

import {
    collection,
    query,
    where,
    getDocs,
    onSnapshot,
    doc,
    getDoc
} from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

document.addEventListener("firebase-auth-ready", () => {

    function loadAllActiveJobs() {
        const table = document.getElementById("activeJobsFullTable");
        table.innerHTML = "";

        const q = query(
            collection(db, "Jobs"),
            where("Status", "in", ["Pending", "Accepted", "In Progress", "Arrived", "On The Way"])
        );

        onSnapshot(q, async (jobSnap) => {
            table.innerHTML = "";

            for (const job of jobSnap.docs) {
                const j = job.data();

                let contractorName = "N/A";
                if (j.ContractorAssigned && j.ContractorAssigned.id) {
                    const csnap = await getDoc(j.ContractorAssigned);
                    if (csnap.exists()) contractorName = csnap.data().FullName || csnap.data().Name || "N/A";
                }

                let badge = "badge badge-green";
                if (j.Status === "Pending") badge = "badge badge-red";
                else if (j.Status === "In Progress") badge = "badge badge-orange";
                else if (j.Status === "On The Way") badge = "badge badge-yellow";

                table.innerHTML += `
                    <tr class="border-b border-[#333]">
                        <td class="py-3">${job.id}</td>
                        <td class="py-3">${j.ServiceType || "N/A"}</td>
                        <td class="py-3">${j.UserLocation || "N/A"}</td>
                        <td class="py-3"><span class="${badge}">${j.Status}</span></td>
                        <td class="py-3">${contractorName}</td>
                    </tr>
                `;
            }
        });
    }

    loadAllActiveJobs();
});

</script>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

<div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333] mb-10">
    <h2 class="text-xl font-semibold mb-4">Active Job List</h2>

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
        <tbody id="activeJobsFullTable"></tbody>
    </table>
</div>

</asp:Content>

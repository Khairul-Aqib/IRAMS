<%@ Page Title="" Language="C#" MasterPageFile="~/Site1.Master" AutoEventWireup="true"
    CodeBehind="RecentJobList.aspx.cs" Inherits="AdminPage.RecentJobList" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Recent Job List
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

    document.addEventListener("firebase-auth-ready", () => {

        function loadAllInvoices() {
            const table = document.getElementById("allInvoicesTable");
            table.innerHTML = "";

            const q = query(
                collection(db, "JobInvoice"),
                orderBy("RequestedTime", "desc")
            );

            onSnapshot(q, async (snap) => {
                table.innerHTML = "";

                for (const invoice of snap.docs) {
                const d = invoice.data();

                // User Lookup 
                let userName = "Unknown";

                try {
                    if (d.UserID) {
                        let userSnap = null;

                        // Case 1: Firestore DocumentReference
                        if (typeof d.UserID === "object" && d.UserID.path) {
                            userSnap = await getDoc(d.UserID);
                        }
                        // Case 2: String ID or path
                        else if (typeof d.UserID === "string") {
                            const uid = d.UserID.replace("/Users/", "").replace("Users/", "");
                            userSnap = await getDoc(doc(db, "Users", uid));
                        }

                        if (userSnap && userSnap.exists()) {
                            const u = userSnap.data();
                            userName = u.FullName || u.Name || "Unknown";
                        }
                    }
                } catch (err) {
                    console.warn("User lookup failed:", d.UserID, err);
                }


                // Contractor Lookup
                let contractorName = "Unknown";
                if (d.ContractorID) {
                    const contractorSnap = await getDoc(
                        doc(db, "Contractor", d.ContractorID)
                    );
                    if (contractorSnap.exists()) {
                        const c = contractorSnap.data();
                        contractorName = c.CompanyName || c.FullName || d.ContractorID;
                    }
                }

                table.innerHTML += `
                <tr class="border-b border-[#333]">
                    <td class="py-3">${invoice.id}</td>
                    <td class="py-3">${userName}</td>
                    <td class="py-3">${d.UserLocation || "N/A"}</td>
                    <td class="py-3">${d.ServiceType || "N/A"}</td>
                    <td class="py-3">RM ${(Number(d.TotalCost) || 0).toFixed(2)}</td>
                    <td class="py-3">${d.PaymentMethod || "N/A"}</td>
                    <td class="py-3">${contractorName}</td>
                </tr>`;
                }
            });
        }

        loadAllInvoices();
    });
</script>
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

<div class="bg-[#1f1f1f] p-6 rounded-xl border border-[#333] mb-10">
    <h2 class="text-xl font-semibold mb-4">Recent Job Invoices</h2>

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
        <tbody id="allInvoicesTable"></tbody>
    </table>
</div>

</asp:Content>

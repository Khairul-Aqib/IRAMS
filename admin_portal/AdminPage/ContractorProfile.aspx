<%@ Page Title="Contractor Profile" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="ContractorProfile.aspx.cs" Inherits="AdminPage.ContractorProfile" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Contractor Profile
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">
        Contractors Management &gt; <span id="profileContractorNameTitle">Contractor</span>
    </h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8">

        <!-- top section -->
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-6 mb-8">
            <!-- name -->
            <div class="flex items-center gap-5">
                <div class="w-24 h-24 rounded-full bg-gray-600 overflow-hidden">
                    <img id="profileImage"
                         src="https://via.placeholder.com/150"
                         alt="Profile"
                         class="w-full h-full object-cover" />
                </div>
                <div>
                    <h2 id="profileFullName" class="text-2xl font-bold mb-1">Full Name</h2>
                    <p class="text-sm text-gray-400">
                        Last Login:
                        <span id="profileLastLogin">-</span>
                    </p>
                </div>
            </div>

            <!-- buttons -->
            <div class="flex gap-3">
                <asp:HyperLink ID="lnkSuspendContractor" runat="server"
                    NavigateUrl="#"
                    CssClass="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-yellow-500 hover:bg-yellow-600 text-black font-semibold text-sm cursor-pointer">
                    Suspend
                </asp:HyperLink>

                <asp:HyperLink ID="lnkDeleteContractor" runat="server"
                    NavigateUrl="#"
                    CssClass="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white font-semibold text-sm cursor-pointer">
                    Deactivate
                </asp:HyperLink>

                <asp:HyperLink ID="lnkEditContractor" runat="server"
                    CssClass="inline-flex items-center justify-center px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white font-semibold text-sm cursor-pointer">
                    Edit
                </asp:HyperLink>
            </div>
        </div>

        <!-- details grid -->
        <div class="grid md:grid-cols-2 gap-6 mb-8">
            <div>
                <p class="text-sm font-semibold mb-1">Full Name</p>
                <div id="detailFullName" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Email Address</p>
                <div id="detailEmail" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Phone Number</p>
                <div id="detailPhone" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Service Types</p>
                <div id="detailServiceTypes" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>
            </div>

            <div>
                <p class="text-sm font-semibold mb-1">Account Status</p>
                <div id="detailAccountStatus" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Company Name</p>
                <div id="detailCompanyName" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Company Contact Phone</p>
                <div id="detailCompanyPhone" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>

                <p class="text-sm font-semibold mt-4 mb-1">Verification Status</p>
                <div id="detailVerificationStatus" class="bg-[#2a2a2a] rounded-lg px-4 py-2 text-sm">-</div>
            </div>
        </div>

        <!-- Verification Documents (loaded dynamically from ComplianceDocumentsMetadata) -->
        <h3 class="text-lg font-semibold mb-3">Verification Documents</h3>
        <div id="contractorDocsGrid" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 mb-8">
            <p class="text-gray-400 text-sm col-span-full">Loading documents...</p>
        </div>

        <!-- Approval Action Buttons (visible only when documents need review) -->
        <div id="approvalActions" class="hidden mb-8 p-5 rounded-xl border border-yellow-500/40 bg-yellow-500/5">
            <h3 class="text-lg font-semibold mb-3 text-yellow-400">Verification Decision</h3>
            <p class="text-sm text-gray-400 mb-4">
                This contractor has documents awaiting verification. Review the documents above, then approve or reject.
            </p>
            <div class="flex gap-4">
                <button type="button" id="btnApproveContractor"
                        class="px-8 py-3 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-base cursor-pointer">
                    Approve Contractor
                </button>
                <button type="button" id="btnRejectContractor"
                        class="px-8 py-3 rounded-lg bg-red-600 hover:bg-red-700 text-white font-semibold text-base cursor-pointer">
                    Reject Contractor
                </button>
            </div>
        </div>

        <!-- Waiting badge (shown when rejected and no pending documents to review) -->
        <div id="waitingBadge" class="hidden mb-8 p-4 rounded-xl border border-gray-600/40 bg-gray-600/5">
            <p class="text-sm text-gray-400">
                <span class="inline-block w-2 h-2 rounded-full bg-yellow-500 mr-2"></span>
                Waiting for contractor to upload revised documents.
            </p>
        </div>

        <!-- Rejection Reason Modal -->
        <div id="rejectionReasonModal"
             class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
            <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
                <h3 class="text-lg font-semibold mb-2">Reject Contractor</h3>
                <p class="text-sm text-gray-600 mb-4">
                    Please enter the exact reason for rejection (e.g., Image blurry, Expired license):
                </p>
                <textarea id="rejectionReasonInput"
                          rows="3"
                          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm mb-4 focus:outline-none focus:ring-2 focus:ring-red-400"
                          placeholder="Enter rejection reason..."></textarea>
                <div class="flex justify-end gap-3">
                    <button type="button" id="btnCancelRejection"
                            class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300 cursor-pointer">
                        Cancel
                    </button>
                    <button type="button" id="btnConfirmRejection"
                            class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 cursor-pointer">
                        Confirm Rejection
                    </button>
                </div>
            </div>
        </div>

        <!-- Job History table -->
        <h3 class="text-lg font-semibold mb-3">Job History</h3>
        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Date</th>
                        <th class="py-3 px-4 text-left">Job ID</th>
                        <th class="py-3 px-4 text-left">Service Type</th>
                        <th class="py-3 px-4 text-left">Amount</th>
                    </tr>
                </thead>
                <tbody id="contractorJobsBody">
                    <tr>
                        <td colspan="4" class="py-4 px-4 text-center text-gray-400">
                            Loading job history...
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
        <div id="jobHistoryPagination" class="flex justify-end items-center gap-2 mt-4"></div>
    </div>

    <!-- Delete modal -->
    <div id="deleteContractorModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">
            <h3 class="text-lg font-semibold mb-2">Deactivate Contractor?</h3>
            <p class="text-sm text-gray-600 mb-6">
                Are you sure you want to Deactivate and archive this contractor? Their account will be locked, but their job history will be preserved for accounting.
            </p>
            <div class="flex justify-end gap-3">
                <button type="button"
                        id="btnCancelDeleteContractor"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300 cursor-pointer">
                    Cancel
                </button>
                <button type="button"
                        id="btnConfirmDeleteContractor"
                        class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 cursor-pointer">
                    Confirm
                </button>
            </div>
        </div>
    </div>

    <!-- Suspend/Activate modal -->
    <div id="suspendContractorModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-white rounded-xl p-6 w-full max-w-md text-[#111]">

            <h3 id="suspendModalTitle" class="text-lg font-semibold mb-2">Suspend Contractor?</h3>
            <p id="suspendModalText" class="text-sm text-gray-600 mb-6">
                Contractor will immediately lose access. Are you sure you want to suspend this contractor?
            </p>

            <div class="flex justify-end gap-3">
                <button type="button"
                        id="btnCancelSuspendContractor"
                        class="px-4 py-2 rounded-lg bg-gray-200 text-gray-800 hover:bg-gray-300 cursor-pointer">
                    Cancel
                </button>
                <button type="button"
                        id="btnConfirmSuspendContractor"
                        class="px-4 py-2 rounded-lg bg-yellow-500 text-black hover:bg-yellow-600 cursor-pointer">
                    Confirm Suspend
                </button>
            </div>
        </div>
    </div>

    <!-- Document Lightbox Modal -->
    <div id="docLightbox"
         class="fixed inset-0 bg-black/80 flex items-center justify-center z-50 hidden cursor-pointer">
        <button type="button" id="btnCloseLightbox"
                class="absolute top-4 right-6 text-white text-3xl font-bold hover:text-gray-300 cursor-pointer">&times;</button>
        <img id="lightboxImage" src="" alt="Document"
             class="max-h-[90vh] max-w-[90vw] rounded-lg shadow-2xl" />
    </div>

    <script type="module">
        import {
            doc,
            getDoc,
            updateDoc,
            collection,
            query,
            where,
            getDocs,
            addDoc,
            serverTimestamp
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        function getAdminName() {
            const el = document.querySelector('[id$="lblAdminName"]');
            const raw = el ? el.textContent.replace("(Admin)", "").trim() : "";
            return raw || "System Admin";
        }

        let contractorId = null;
        let contractorDocRef = null;
        let accountStatus = "Active";
        let isDeleted = false;
        let suspendAction = "suspend";

        // Job History pagination
        let allJobsHistory = [];
        let currentJobPage = 1;
        const jobsPerPage = 5;

        // Human-readable labels for ComplianceDocumentsMetadata slugs
        const DOC_SLUG_LABELS = {
            selfie:          "Live Selfie",
            profile_picture: "Live Selfie",
            ic_front:        "NRIC (MyKad) Front",
            ic_back:         "NRIC (MyKad) Back",
            driving_licence: "Driving License (GDL/Class E)",
            gdl_license:     "Driving License (GDL/Class E)",
            vehicle_grant:   "Vehicle Grant (VOC/Geran)",
            puspakom:        "PUSPAKOM Inspection Cert"
        };

        function formatDateTime(value) {
            if (!value) return "";
            if (typeof value.toDate === "function") return formatDateToString(value.toDate());
            const d = new Date(value);
            if (!isNaN(d.getTime())) return formatDateToString(d);
            return value.toString();
        }

        function formatDateToString(d) {
            const day = String(d.getDate()).padStart(2, "0");
            const month = String(d.getMonth() + 1).padStart(2, "0");
            const year = d.getFullYear();
            const hours = String(d.getHours()).padStart(2, "0");
            const minutes = String(d.getMinutes()).padStart(2, "0");
            return `${day}/${month}/${year} ${hours}:${minutes}`;
        }

        function formatDateOnly(value) {
            if (!value) return "";

            let d;
            if (typeof value.toDate === "function") {
                d = value.toDate();
            } else {
                d = new Date(value);
            }

            if (!isNaN(d.getTime())) {
                const day = String(d.getDate()).padStart(2, "0");
                const month = String(d.getMonth() + 1).padStart(2, "0");
                const year = d.getFullYear();
                return `${day}/${month}/${year}`;
            }

            return value.toString();
        }

        document.addEventListener("firebase-auth-ready", async () => {
            const params = new URLSearchParams(window.location.search);
            contractorId = params.get("id");

            if (!contractorId) {
                alert("No contractor id.");
                window.location.href = "Contractors.aspx";
                return;
            }

            contractorDocRef = doc(db, "Contractor", contractorId);
            await loadContractorProfile();
            await loadContractorJobInvoices();

            // Edit link
            const editLink = document.getElementById("<%= lnkEditContractor.ClientID %>");
            editLink.href = "ContractorEdit.aspx?id=" + contractorId;

            setupDeleteModal();
            setupSuspendModal();
            setupApprovalButtons();
            setupRejectionModal();
            setupLightbox();
        });

        // ── Document grid rendering (from ComplianceDocumentsMetadata) ──
        function renderDocuments(complianceDocsMetadata) {
            const grid = document.getElementById("contractorDocsGrid");
            grid.innerHTML = "";

            if (!complianceDocsMetadata || typeof complianceDocsMetadata !== "object" || Object.keys(complianceDocsMetadata).length === 0) {
                grid.innerHTML = '<p class="text-gray-400 text-sm col-span-full">No compliance documents found.</p>';
                return;
            }

            // Sort: Live Selfie first, then remaining docs in their natural order
            const SELFIE_SLUGS = ["selfie", "profile_picture"];
            const sortedEntries = Object.entries(complianceDocsMetadata).sort((a, b) => {
                const aIsSelfie = SELFIE_SLUGS.includes(a[0]);
                const bIsSelfie = SELFIE_SLUGS.includes(b[0]);
                if (aIsSelfie && !bIsSelfie) return -1;
                if (!aIsSelfie && bIsSelfie) return 1;
                return 0;
            });

            for (const [slug, meta] of sortedEntries) {
                const label = DOC_SLUG_LABELS[slug] || slug.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
                const url = meta.url || "";
                const docStatus = (meta.status || "pending").toLowerCase();
                const rejectionReason = meta.rejectionReason || "";

                // Expiry date for documents that have one
                const hasExpiry = ["driving_licence", "gdl_license", "vehicle_grant", "puspakom"].includes(slug);
                let expiryHtml = "";
                if (hasExpiry) {
                    const rawExpiry = meta.expiry || meta.Expiry || meta.expiryDate || meta.ExpiryDate || null;
                    let expiryString = "N/A";
                    if (rawExpiry) {
                        const ed = typeof rawExpiry.toDate === "function" ? rawExpiry.toDate() : new Date(rawExpiry);
                        if (!isNaN(ed.getTime())) {
                            expiryString = `${String(ed.getDate()).padStart(2, "0")}/${String(ed.getMonth() + 1).padStart(2, "0")}/${ed.getFullYear()}`;
                        }
                    }
                    expiryHtml = `<p class="text-xs text-gray-400 mt-1">Expires: ${expiryString}</p>`;
                }

                const card = document.createElement("div");
                card.className = "bg-[#262626] rounded-xl border border-[#333] overflow-hidden";

                // Status badge
                let badgeBg = "bg-yellow-600";
                let badgeText = "Pending";
                if (docStatus === "approved") {
                    badgeBg = "bg-emerald-600";
                    badgeText = "Approved";
                } else if (docStatus === "rejected") {
                    badgeBg = "bg-red-600";
                    badgeText = "Rejected";
                } else if (docStatus === "uploaded" || url) {
                    badgeBg = "bg-blue-600";
                    badgeText = "Uploaded";
                }

                if (url) {
                    card.innerHTML = `
                        <div class="cursor-pointer doc-thumb" data-url="${url}">
                            <img src="${url}" alt="${label}"
                                 class="w-full h-48 object-cover" />
                        </div>
                        <div class="px-4 py-3">
                            <div class="flex items-center justify-between mb-1">
                                <span class="text-sm font-semibold">${label}</span>
                                <span class="px-2 py-0.5 rounded text-xs ${badgeBg} text-white">${badgeText}</span>
                            </div>
                            ${expiryHtml}
                            ${rejectionReason ? `<p class="text-xs text-red-400 mt-1">Reason: ${rejectionReason}</p>` : ""}
                        </div>
                    `;
                } else {
                    card.innerHTML = `
                        <div class="w-full h-48 flex items-center justify-center bg-[#1a1a1a]">
                            <svg class="w-12 h-12 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                        </div>
                        <div class="px-4 py-3">
                            <div class="flex items-center justify-between mb-1">
                                <span class="text-sm font-semibold">${label}</span>
                                <span class="px-2 py-0.5 rounded text-xs bg-gray-600 text-white">Not Uploaded</span>
                            </div>
                            ${expiryHtml}
                        </div>
                    `;
                }

                grid.appendChild(card);
            }

            // Attach click-to-lightbox on thumbnails
            grid.querySelectorAll(".doc-thumb").forEach(thumb => {
                thumb.addEventListener("click", () => {
                    openLightbox(thumb.dataset.url);
                });
            });
        }

        // ── Lightbox ─────────────────────────────────────────────
        function openLightbox(url) {
            const lb = document.getElementById("docLightbox");
            document.getElementById("lightboxImage").src = url;
            lb.classList.remove("hidden");
        }

        function setupLightbox() {
            const lb = document.getElementById("docLightbox");
            document.getElementById("btnCloseLightbox").addEventListener("click", () => lb.classList.add("hidden"));
            lb.addEventListener("click", (e) => { if (e.target === lb) lb.classList.add("hidden"); });
        }

        // ── Approval workflow ────────────────────────────────────
        function showApprovalIfNeeded(verificationStatus, complianceDocs) {
            const panel = document.getElementById("approvalActions");
            const waitingBadge = document.getElementById("waitingBadge");
            const globalStatus = (verificationStatus || "").toLowerCase();

            // Check if any document has a reviewable status
            const docs = complianceDocs || {};
            const hasReviewable = Object.values(docs).some(meta => {
                const s = (meta.status || "").toLowerCase();
                return s === "uploaded" || s === "pending" || s === "under_review";
            });

            if (hasReviewable) {
                // Documents need review — show action buttons
                panel.classList.remove("hidden");
                waitingBadge.classList.add("hidden");
            } else if (globalStatus === "rejected") {
                // All docs are approved or rejected, but contractor is still rejected overall
                panel.classList.add("hidden");
                waitingBadge.classList.remove("hidden");
            } else {
                // Fully approved or no action needed
                panel.classList.add("hidden");
                waitingBadge.classList.add("hidden");
            }
        }

        function setupApprovalButtons() {
            document.getElementById("btnApproveContractor").addEventListener("click", async () => {
                if (!confirm("Review and approve pending documents for this contractor?")) return;

                try {
                    // Fetch latest doc to read current metadata and selfie
                    const snap = await getDoc(contractorDocRef);
                    if (!snap.exists()) {
                        alert("Contractor not found.");
                        return;
                    }

                    const c = snap.data();
                    const selfieUrl = c.SubmittedSelfieUrl || "";
                    const complianceDocs = c.ComplianceDocumentsMetadata || {};

                    // Smart approve: only approve documents in a pending/uploaded state.
                    // Leave rejected and missing documents untouched.
                    const updatedDocs = {};
                    const approvedItems = [];
                    const stillRejected = [];

                    for (const [slug, meta] of Object.entries(complianceDocs)) {
                        const currentStatus = (meta.status || "").toLowerCase();

                        if (currentStatus === "uploaded" || currentStatus === "under_review" || currentStatus === "pending") {
                            // Approve this document
                            updatedDocs[slug] = {
                                ...meta,
                                status: "approved",
                                rejectionReason: ""
                            };
                            approvedItems.push(slug);
                        } else if (currentStatus === "rejected") {
                            // Leave rejected documents exactly as they are
                            updatedDocs[slug] = { ...meta };
                            const label = DOC_SLUG_LABELS[slug] || slug.replace(/_/g, " ").replace(/\b\w/g, ch => ch.toUpperCase());
                            stillRejected.push(label);
                        } else {
                            // Preserve any other status (approved, missing, etc.)
                            updatedDocs[slug] = { ...meta };
                        }
                    }

                    // Global status validation: all documents must be approved
                    const allApproved = Object.values(updatedDocs).every(
                        m => (m.status || "").toLowerCase() === "approved"
                    );

                    const updatePayload = {
                        ComplianceDocumentsMetadata: updatedDocs
                    };

                    if (allApproved) {
                        updatePayload.VerificationStatus = "approved";
                        // Copy selfie into ApprovedProfileImageUrl
                        if (selfieUrl) {
                            updatePayload.ApprovedProfileImageUrl = selfieUrl;
                        }
                    } else {
                        // Keep global status as rejected — not fully compliant
                        updatePayload.VerificationStatus = "rejected";
                    }

                    await updateDoc(contractorDocRef, updatePayload);

                    // Write to compliance audit log
                    await addDoc(collection(db, "ComplianceLogs"), {
                        ContractorID: contractorId,
                        ContractorName: c.FullName || "-",
                        Action: allApproved ? "Approved" : "Partial Approval",
                        Timestamp: serverTimestamp(),
                        Admin: getAdminName(),
                        ApprovedItems: approvedItems,
                        StillRejected: stillRejected,
                        DocumentSnapshot: {
                            SubmittedSelfieUrl: c.SubmittedSelfieUrl || "",
                            IcFrontUrl: c.IcFrontUrl || "",
                            IcBackUrl: c.IcBackUrl || "",
                            ComplianceDocumentsMetadata: complianceDocs
                        }
                    });

                    if (allApproved) {
                        alert("Contractor approved successfully. All documents are verified.");
                    } else {
                        alert(
                            "Pending documents approved, but the contractor remains Rejected because the following documents are still rejected:\n\n- " +
                            stillRejected.join("\n- ")
                        );
                    }
                    window.location.reload();
                } catch (err) {
                    console.error("Error approving contractor:", err);
                    alert("Failed to approve contractor.");
                }
            });

            // Reject button opens the rejection reason modal
            document.getElementById("btnRejectContractor").addEventListener("click", () => {
                document.getElementById("rejectionReasonInput").value = "";
                document.getElementById("rejectionReasonModal").classList.remove("hidden");
            });
        }

        // ── Rejection modal workflow ─────────────────────────────
        function setupRejectionModal() {
            const modal = document.getElementById("rejectionReasonModal");
            const btnCancel = document.getElementById("btnCancelRejection");
            const btnConfirm = document.getElementById("btnConfirmRejection");

            btnCancel.addEventListener("click", () => {
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                const reason = document.getElementById("rejectionReasonInput").value.trim();

                if (!reason) {
                    alert("Please enter a rejection reason before confirming.");
                    return;
                }

                try {
                    // Fetch latest doc to read current metadata
                    const snap = await getDoc(contractorDocRef);
                    if (!snap.exists()) {
                        alert("Contractor not found.");
                        return;
                    }

                    const c = snap.data();
                    const complianceDocs = c.ComplianceDocumentsMetadata || {};

                    // Smart reject: only reject documents that are in a pending/uploaded state.
                    // Documents already "approved" are left untouched.
                    const updatedDocs = {};
                    const rejectedItems = [];

                    for (const [slug, meta] of Object.entries(complianceDocs)) {
                        const currentStatus = (meta.status || "").toLowerCase();

                        if (currentStatus === "approved") {
                            // Preserve approved documents exactly as they are
                            updatedDocs[slug] = { ...meta };
                        } else {
                            // Reject any non-approved document (uploaded, pending, under_review, empty)
                            updatedDocs[slug] = {
                                ...meta,
                                status: "rejected",
                                rejectionReason: reason
                            };
                            rejectedItems.push(slug);
                        }
                    }

                    await updateDoc(contractorDocRef, {
                        VerificationStatus: "rejected",
                        ComplianceDocumentsMetadata: updatedDocs
                    });

                    // Write to compliance audit log
                    await addDoc(collection(db, "ComplianceLogs"), {
                        ContractorID: contractorId,
                        ContractorName: c.FullName || "-",
                        Action: "Rejected",
                        RejectionReason: reason,
                        RejectedItems: rejectedItems,
                        Timestamp: serverTimestamp(),
                        Admin: getAdminName(),
                        DocumentSnapshot: {
                            SubmittedSelfieUrl: c.SubmittedSelfieUrl || "",
                            IcFrontUrl: c.IcFrontUrl || "",
                            IcBackUrl: c.IcBackUrl || "",
                            ComplianceDocumentsMetadata: complianceDocs
                        }
                    });

                    modal.classList.add("hidden");
                    alert("Contractor rejected. " + rejectedItems.length + " document(s) marked as rejected.");
                    window.location.reload();
                } catch (err) {
                    console.error("Error rejecting contractor:", err);
                    alert("Failed to reject contractor.");
                }
            });
        }

        // ── Load profile ─────────────────────────────────────────
        async function loadContractorProfile() {
            try {
                const snap = await getDoc(contractorDocRef);
                if (!snap.exists()) {
                    alert("Contractor not found.");
                    window.location.href = "Contractors.aspx";
                    return;
                }

                const c = snap.data();

                document.getElementById("profileContractorNameTitle").textContent = c.FullName || "Contractor";
                document.getElementById("profileFullName").textContent = c.FullName || "-";
                document.getElementById("profileLastLogin").textContent = formatDateTime(c.LastLogin) || "-";

                document.getElementById("detailFullName").textContent = c.FullName || "-";
                document.getElementById("detailEmail").textContent = c.Email || "-";
                document.getElementById("detailPhone").textContent = c.PhoneNumber || "-";

                const svcText = Array.isArray(c.ServiceTypes)
                    ? c.ServiceTypes.join(", ")
                    : (c.ServiceTypes || "-");
                document.getElementById("detailServiceTypes").textContent = svcText;

                document.getElementById("detailAccountStatus").textContent = c.AccountStatus || "-";
                document.getElementById("detailCompanyName").textContent = c.CompanyName || "-";
                document.getElementById("detailCompanyPhone").textContent = c.CompanyContactPhone || "-";
                document.getElementById("detailVerificationStatus").textContent = c.VerificationStatus || "Pending";

                // Profile image: prefer ApprovedProfileImageUrl, then fall back to SubmittedSelfieUrl
                const profileImgUrl = c.ApprovedProfileImageUrl || c.SubmittedSelfieUrl || "";
                if (profileImgUrl) {
                    document.getElementById("profileImage").src = profileImgUrl;
                } else {
                    document.getElementById("profileImage").src = "images/default-avatar.png";
                }

                accountStatus = c.AccountStatus || "Active";
                isDeleted = c.IsDeleted === true;
                updateSuspendButtonUI();
                updateDeleteButtonUI();

                // Render compliance documents from ComplianceDocumentsMetadata map
                renderDocuments(c.ComplianceDocumentsMetadata || {});

                // Show approval panel only if there are documents to review
                showApprovalIfNeeded(c.VerificationStatus, c.ComplianceDocumentsMetadata);
            } catch (err) {
                console.error("Error loading contractor profile:", err);
                alert("Failed to load profile.");
            }
        }

        // ── Job History (paginated) ─────────────────────────────
        async function loadContractorJobInvoices() {
            try {
                const jobInvoiceRef = collection(db, "JobInvoice");
                const q = query(jobInvoiceRef, where("ContractorID", "==", contractorId));
                const querySnapshot = await getDocs(q);

                if (querySnapshot.empty) {
                    allJobsHistory = [];
                    document.getElementById("contractorJobsBody").innerHTML = `
                        <tr>
                            <td colspan="4" class="py-4 px-4 text-center text-gray-400">
                                No completed jobs found for this contractor.
                            </td>
                        </tr>
                    `;
                    document.getElementById("jobHistoryPagination").innerHTML = "";
                    return;
                }

                // Store all jobs and sort newest first
                allJobsHistory = [];
                querySnapshot.forEach((docSnap) => {
                    allJobsHistory.push(docSnap.data());
                });
                allJobsHistory.sort((a, b) => {
                    const da = a.RequestedTime ? (typeof a.RequestedTime.toDate === "function" ? a.RequestedTime.toDate() : new Date(a.RequestedTime)) : new Date(0);
                    const db2 = b.RequestedTime ? (typeof b.RequestedTime.toDate === "function" ? b.RequestedTime.toDate() : new Date(b.RequestedTime)) : new Date(0);
                    return db2 - da;
                });

                currentJobPage = 1;
                renderJobPage(currentJobPage);

            } catch (err) {
                console.error("Error loading job history:", err);
                document.getElementById("contractorJobsBody").innerHTML = `
                    <tr>
                        <td colspan="4" class="py-4 px-4 text-center text-red-400">
                            Error loading job history. Please try again.
                        </td>
                    </tr>
                `;
                document.getElementById("jobHistoryPagination").innerHTML = "";
            }
        }

        function renderJobPage(page) {
            const tbody = document.getElementById("contractorJobsBody");
            const start = (page - 1) * jobsPerPage;
            const paginatedJobs = allJobsHistory.slice(start, start + jobsPerPage);

            tbody.innerHTML = "";
            paginatedJobs.forEach((invoice) => {
                const row = document.createElement("tr");
                row.className = "border-t border-[#333] hover:bg-[#252525]";
                row.innerHTML = `
                    <td class="py-3 px-4">${formatDateOnly(invoice.RequestedTime) || "-"}</td>
                    <td class="py-3 px-4">${invoice.JobID || "-"}</td>
                    <td class="py-3 px-4">${invoice.ServiceType || "-"}</td>
                    <td class="py-3 px-4">RM ${invoice.TotalCost || "0"}</td>
                `;
                tbody.appendChild(row);
            });

            renderJobPaginationControls();
        }

        function renderJobPaginationControls() {
            const container = document.getElementById("jobHistoryPagination");
            const totalPages = Math.ceil(allJobsHistory.length / jobsPerPage);

            if (totalPages <= 1) {
                container.innerHTML = "";
                return;
            }

            container.innerHTML = "";

            // Previous button
            const prevBtn = document.createElement("button");
            prevBtn.type = "button";
            prevBtn.textContent = "Previous";
            prevBtn.className = currentJobPage === 1
                ? "px-3 py-1.5 rounded-lg bg-gray-700 text-gray-500 text-sm cursor-not-allowed"
                : "px-3 py-1.5 rounded-lg bg-[#333] text-white text-sm hover:bg-[#444] cursor-pointer";
            prevBtn.disabled = currentJobPage === 1;
            prevBtn.addEventListener("click", () => {
                if (currentJobPage > 1) {
                    currentJobPage--;
                    renderJobPage(currentJobPage);
                }
            });
            container.appendChild(prevBtn);

            // Page numbers
            for (let i = 1; i <= totalPages; i++) {
                const pageBtn = document.createElement("button");
                pageBtn.type = "button";
                pageBtn.textContent = i;
                pageBtn.className = i === currentJobPage
                    ? "px-3 py-1.5 rounded-lg bg-yellow-500 text-black text-sm font-semibold cursor-default"
                    : "px-3 py-1.5 rounded-lg bg-[#333] text-white text-sm hover:bg-[#444] cursor-pointer";
                pageBtn.addEventListener("click", () => {
                    currentJobPage = i;
                    renderJobPage(currentJobPage);
                });
                container.appendChild(pageBtn);
            }

            // Next button
            const nextBtn = document.createElement("button");
            nextBtn.type = "button";
            nextBtn.textContent = "Next";
            nextBtn.className = currentJobPage === totalPages
                ? "px-3 py-1.5 rounded-lg bg-gray-700 text-gray-500 text-sm cursor-not-allowed"
                : "px-3 py-1.5 rounded-lg bg-[#333] text-white text-sm hover:bg-[#444] cursor-pointer";
            nextBtn.disabled = currentJobPage === totalPages;
            nextBtn.addEventListener("click", () => {
                if (currentJobPage < totalPages) {
                    currentJobPage++;
                    renderJobPage(currentJobPage);
                }
            });
            container.appendChild(nextBtn);
        }

        // ── Suspend / Activate ───────────────────────────────────
        function updateSuspendButtonUI() {
            const btn = document.getElementById("<%= lnkSuspendContractor.ClientID %>");
            if (!btn) return;

            const lower = (accountStatus || "").toLowerCase();

            if (lower === "active") {
                btn.textContent = "Suspend";
                btn.dataset.action = "suspend";
                btn.className = "inline-flex items-center justify-center px-4 py-2 rounded-lg bg-yellow-500 hover:bg-yellow-600 text-black font-semibold text-sm cursor-pointer";
            } else {
                btn.textContent = "Activate";
                btn.dataset.action = "activate";
                btn.className = "inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-white font-semibold text-sm cursor-pointer";
            }
        }

        function updateDeleteButtonUI() {
            const suspendBtn = document.getElementById("<%= lnkSuspendContractor.ClientID %>");
            const deleteBtn = document.getElementById("<%= lnkDeleteContractor.ClientID %>");

            if (isDeleted) {
                // Hide suspend button for archived contractors
                suspendBtn.style.display = "none";

                // Turn deactivate button into restore button
                deleteBtn.textContent = "Restore Account";
                deleteBtn.className = "inline-flex items-center justify-center px-4 py-2 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-white font-semibold text-sm cursor-pointer";
            } else {
                suspendBtn.style.display = "";
                deleteBtn.textContent = "Deactivate";
                deleteBtn.className = "inline-flex items-center justify-center px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white font-semibold text-sm cursor-pointer";
            }
        }

        function setupDeleteModal() {
            const modal = document.getElementById("deleteContractorModal");
            const modalTitle = modal.querySelector("h3");
            const modalText = modal.querySelector("p");
            const btnCancel = document.getElementById("btnCancelDeleteContractor");
            const btnConfirm = document.getElementById("btnConfirmDeleteContractor");
            const deleteBtn = document.getElementById("<%= lnkDeleteContractor.ClientID %>");

            deleteBtn.addEventListener("click", (e) => {
                e.preventDefault();

                if (isDeleted) {
                    // Restore flow
                    modalTitle.textContent = "Restore Contractor?";
                    modalText.textContent = "This will reactivate the contractor's account and restore their access. Are you sure?";
                    btnConfirm.textContent = "Confirm Restore";
                    btnConfirm.className = "px-4 py-2 rounded-lg bg-emerald-500 text-white hover:bg-emerald-600 cursor-pointer";
                } else {
                    // Deactivate flow
                    modalTitle.textContent = "Deactivate Contractor?";
                    modalText.textContent = "Are you sure you want to Deactivate and archive this contractor? Their account will be locked, but their job history will be preserved for accounting.";
                    btnConfirm.textContent = "Confirm";
                    btnConfirm.className = "px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-600 cursor-pointer";
                }

                modal.classList.remove("hidden");
            });

            btnCancel.addEventListener("click", () => {
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                try {
                    if (isDeleted) {
                        // Restore
                        await updateDoc(contractorDocRef, {
                            IsDeleted: false,
                            AccountStatus: "Active"
                        });
                        isDeleted = false;
                        accountStatus = "Active";
                        document.getElementById("detailAccountStatus").textContent = "Active";
                        updateSuspendButtonUI();
                        updateDeleteButtonUI();
                        modal.classList.add("hidden");
                        alert("Contractor account has been restored.");
                    } else {
                        // Deactivate
                        await updateDoc(contractorDocRef, {
                            IsDeleted: true,
                            AccountStatus: "Deactivated"
                        });
                        alert("Contractor has been deactivated and archived.");
                        window.location.href = "Contractors.aspx";
                    }
                } catch (err) {
                    console.error("Error updating contractor:", err);
                }
            });
        }

        function setupSuspendModal() {
            const modal = document.getElementById("suspendContractorModal");
            const btnCancel = document.getElementById("btnCancelSuspendContractor");
            const btnConfirm = document.getElementById("btnConfirmSuspendContractor");
            const titleEl = document.getElementById("suspendModalTitle");
            const textEl = document.getElementById("suspendModalText");
            const btn = document.getElementById("<%= lnkSuspendContractor.ClientID %>");

            btn.addEventListener("click", (e) => {
                e.preventDefault();

                suspendAction = btn.dataset.action || "suspend";
                if (suspendAction === "suspend") {
                    titleEl.textContent = "Suspend Contractor?";
                    textEl.textContent =
                        "Contractor will immediately lose access and won't be able to sign in. Are you sure you want to suspend this contractor?";
                    btnConfirm.textContent = "Confirm Suspend";
                    btnConfirm.className = "px-4 py-2 rounded-lg bg-yellow-500 text-black hover:bg-yellow-600 cursor-pointer";
                } else {
                    titleEl.textContent = "Activate Contractor?";
                    textEl.textContent =
                        "Contractor will regain access. Are you sure you want to activate this contractor?";
                    btnConfirm.textContent = "Confirm Activate";
                    btnConfirm.className = "px-4 py-2 rounded-lg bg-emerald-500 text-white hover:bg-emerald-600 cursor-pointer";
                }

                modal.classList.remove("hidden");
            });

            btnCancel.addEventListener("click", () => {
                modal.classList.add("hidden");
            });

            btnConfirm.addEventListener("click", async () => {
                try {
                    const newStatus = suspendAction === "suspend" ? "Suspended" : "Active";
                    await updateDoc(contractorDocRef, { AccountStatus: newStatus });

                    accountStatus = newStatus;
                    document.getElementById("detailAccountStatus").textContent = newStatus;
                    updateSuspendButtonUI();
                    modal.classList.add("hidden");
                } catch (err) {
                    console.error("Error updating status:", err);
                }
            });
        }
    </script>

</asp:Content>

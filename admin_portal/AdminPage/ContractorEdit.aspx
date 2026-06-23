<%@ Page Title="Edit Contractor" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="ContractorEdit.aspx.cs" Inherits="AdminPage.ContractorEdit" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Edit Contractor
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">
        Contractors Management &gt; Edit Profile
    </h1>

    <style>
        /*Custom dropdown arrow styling*/
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

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8 max-w-4xl">

        <!-- Avatar section -->
        <div class="flex justify-center mb-6">
            <div class="relative">
                <div class="w-28 h-28 rounded-full bg-gray-600 overflow-hidden">
                    <img id="editProfileImage"
                         src="images/default-avatar.png"
                         class="w-full h-full object-cover"
                         alt="Profile" />
                </div>
                <label class="absolute bottom-0 right-0 bg-yellow-500 text-xs font-semibold px-3 py-1 rounded-full cursor-pointer">
                    Upload
                    <input type="file" id="fileProfileImage" accept="image/*" class="hidden" />
                </label>
            </div>
        </div>

        <div class="grid md:grid-cols-2 gap-6 mb-6">
            <div>
                <label class="block text-sm font-semibold mb-1">Full Name</label>
                <asp:TextBox ID="txtFullName" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Email Address</label>
                <asp:TextBox ID="txtEmail" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Phone Number</label>
                <asp:TextBox ID="txtPhone" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Service Types</label>

                <div class="relative" id="serviceTypesWrapper">
                    <!-- fake dropdown button -->
                    <button type="button"
                            id="btnServiceTypes"
                            class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4 flex justify-between items-center text-left">
                        <span id="serviceTypesText" class="text-sm text-gray-200">
                            Select service types
                        </span>
                        <svg class="w-4 h-4 text-gray-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                        </svg>
                    </button>

                    <!-- dropdown panel with checkboxes -->
                    <div id="serviceTypesDropdown"
                         class="absolute mt-1 w-full bg-[#1f1f1f] border border-[#333] rounded-lg shadow-lg z-20 hidden max-h-56 overflow-y-auto">
                        <p class="px-4 py-2 text-sm text-gray-400">Loading services...</p>
                    </div>
                </div>
            </div>

            <div>
                <label class="block text-sm font-semibold mb-1">Company Name</label>
                <asp:TextBox ID="txtCompanyName" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Company Contact Phone</label>
                <asp:TextBox ID="txtCompanyPhone" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Account Status</label>
                <asp:DropDownList ID="ddlAccountStatus" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4 custom-dropdown">
                    <asp:ListItem Text="Active" Value="Active" />
                    <asp:ListItem Text="Suspended" Value="Suspended" />
                </asp:DropDownList>

                <label class="block text-sm font-semibold mt-4 mb-1">Verification Status</label>
                <asp:DropDownList ID="ddlVerificationStatus" runat="server"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4 custom-dropdown">
                    <asp:ListItem Text="Pending Review" Value="under_review" />
                    <asp:ListItem Text="Verified / Approved" Value="approved" />
                    <asp:ListItem Text="Rejected" Value="rejected" />
                </asp:DropDownList>
            </div>
        </div>

        <div class="flex gap-4 mt-8">
            <asp:Button ID="btnSave" runat="server" Text="Save"
                OnClientClick="saveContractorProfile(); return false;"
                CssClass="bg-yellow-500 hover:bg-yellow-600 text-black font-semibold px-8 py-2 rounded-full cursor-pointer" />

            <asp:HyperLink ID="lnkCancel" runat="server" NavigateUrl="~/Contractors.aspx"
                CssClass="bg-gray-500 hover:bg-gray-600 text-white font-semibold px-8 py-2 rounded-full cursor-pointer">
                Cancel
            </asp:HyperLink>
        </div>
    </div>

    <script type="module">
        import {
            doc,
            getDoc,
            updateDoc,
            collection,
            getDocs
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        import {
            getStorage,
            ref,
            uploadBytes,
            getDownloadURL
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-storage.js";

        let contractorId = null;
        let contractorDocRef = null;
        let storage = null;
        let newProfileImageFile = null;

        function updateServiceTypesText() {
            const selected = Array.from(document.querySelectorAll(".svc-option:checked"))
                .map(cb => cb.value);

            const svcText = document.getElementById("serviceTypesText");
            if (selected.length === 0) {
                svcText.textContent = "Select service types";
            } else {
                svcText.textContent = selected.join(", ");
            }
        }

        document.addEventListener("firebase-auth-ready", async () => {
            // Initialize Storage
            storage = getStorage();

            const params = new URLSearchParams(window.location.search);
            contractorId = params.get("id");

            if (!contractorId) {
                alert("No contractor id.");
                window.location.href = "Contractors.aspx";
                return;
            }

            contractorDocRef = doc(db, "Contractor", contractorId);

            // Cancel link to back to profile
            const cancelLink = document.getElementById("<%= lnkCancel.ClientID %>");
            cancelLink.href = "ContractorProfile.aspx?id=" + contractorId;

            // Dropdown behaviour
            const btnSvc = document.getElementById("btnServiceTypes");
            const dropdownSvc = document.getElementById("serviceTypesDropdown");
            const wrapper = document.getElementById("serviceTypesWrapper");

            btnSvc.addEventListener("click", () => {
                dropdownSvc.classList.toggle("hidden");
            });

            // close when click outside
            document.addEventListener("click", (e) => {
                if (!wrapper.contains(e.target)) {
                    dropdownSvc.classList.add("hidden");
                }
            });

            // Load service types from Firestore and generate checkboxes
            await loadServiceTypes();

            // checkboxes change → update label text
            document.querySelectorAll(".svc-option").forEach(cb => {
                cb.addEventListener("change", updateServiceTypesText);
            });

            // Handle profile image upload preview
            const fileInput = document.getElementById("fileProfileImage");
            if (fileInput) {
                fileInput.addEventListener("change", (e) => {
                    const file = e.target.files[0];
                    if (!file) return;
                    newProfileImageFile = file;

                    const reader = new FileReader();
                    reader.onload = e2 => {
                        document.getElementById("editProfileImage").src = e2.target.result;
                    };
                    reader.readAsDataURL(file);
                });
            }

            await loadContractorForEdit();
        });

        async function loadServiceTypes() {
            const dropdown = document.getElementById("serviceTypesDropdown");
            try {
                const snap = await getDocs(collection(db, "Services"));
                dropdown.innerHTML = "";

                snap.forEach(docSnap => {
                    const svc = docSnap.data();
                    const name = svc.ServiceName || "";
                    if (!name) return;

                    const label = document.createElement("label");
                    label.className = "flex items-center gap-2 px-4 py-2 text-sm hover:bg-[#262626] cursor-pointer";
                    label.innerHTML = `
                        <input type="checkbox" value="${name}"
                               class="svc-option accent-yellow-400">
                        <span>${name}</span>
                    `;
                    dropdown.appendChild(label);
                });

                if (dropdown.children.length === 0) {
                    dropdown.innerHTML = '<p class="px-4 py-2 text-sm text-gray-400">No services found.</p>';
                }
            } catch (err) {
                console.error("Error loading service types:", err);
                dropdown.innerHTML = '<p class="px-4 py-2 text-sm text-red-400">Failed to load services.</p>';
            }
        }

        async function loadContractorForEdit() {
            try {
                const snap = await getDoc(contractorDocRef);
                if (!snap.exists()) {
                    alert("Contractor not found.");
                    window.location.href = "Contractors.aspx";
                    return;
                }

                const c = snap.data();
                console.log("Editing contractor:", c);

                document.getElementById("<%= txtFullName.ClientID %>").value = c.FullName || "";
                document.getElementById("<%= txtEmail.ClientID %>").value = c.Email || "";
                document.getElementById("<%= txtPhone.ClientID %>").value = c.PhoneNumber || "";
                document.getElementById("<%= txtCompanyName.ClientID %>").value = c.CompanyName || "";
                document.getElementById("<%= txtCompanyPhone.ClientID %>").value = c.CompanyContactPhone || "";
                document.getElementById("<%= ddlAccountStatus.ClientID %>").value = c.AccountStatus || "Active";

                // Normalize legacy VerificationStatus values to match dropdown options
                const rawVerify = (c.VerificationStatus || "under_review").toLowerCase();
                let normalizedVerify = "under_review";
                if (rawVerify === "approved" || rawVerify === "verified") {
                    normalizedVerify = "approved";
                } else if (rawVerify === "rejected") {
                    normalizedVerify = "rejected";
                }
                document.getElementById("<%= ddlVerificationStatus.ClientID %>").value = normalizedVerify;

                // Service types array
                const svcArray = Array.isArray(c.ServiceTypes)
                    ? c.ServiceTypes
                    : (c.ServiceTypes
                        ? c.ServiceTypes.toString().split(",").map(x => x.trim())
                        : []);

                document.querySelectorAll(".svc-option").forEach(cb => {
                    cb.checked = svcArray.includes(cb.value);
                });
                updateServiceTypesText();

                // Profile image: prefer ApprovedProfileImageUrl, then SubmittedSelfieUrl
                const profileImgUrl = c.ApprovedProfileImageUrl || c.SubmittedSelfieUrl || "";
                if (profileImgUrl) {
                    document.getElementById("editProfileImage").src = profileImgUrl;
                } else {
                    document.getElementById("editProfileImage").src = "images/default-avatar.png";
                }
            } catch (err) {
                console.error("Error loading contractor for edit:", err);
                alert("Failed to load contractor data.");
            }
        }

        window.saveContractorProfile = async function () {
            if (!contractorDocRef) return;

            const fullName          = document.getElementById("<%= txtFullName.ClientID %>").value.trim();
            const email             = document.getElementById("<%= txtEmail.ClientID %>").value.trim();
            const phone             = document.getElementById("<%= txtPhone.ClientID %>").value.trim();
            const companyName       = document.getElementById("<%= txtCompanyName.ClientID %>").value.trim();
            const companyPhone      = document.getElementById("<%= txtCompanyPhone.ClientID %>").value.trim();
            const accountStatus     = document.getElementById("<%= ddlAccountStatus.ClientID %>").value;
            const verificationStatus= document.getElementById("<%= ddlVerificationStatus.ClientID %>").value;

            // get selected service types
            const selectedServiceTypes = Array
                .from(document.querySelectorAll(".svc-option:checked"))
                .map(cb => cb.value);

            if (!fullName || !email) {
                alert("Full Name and Email are required.");
                return;
            }

            try {
                const updateData = {
                    FullName: fullName,
                    Email: email,
                    PhoneNumber: phone,
                    CompanyName: companyName,
                    CompanyContactPhone: companyPhone,
                    AccountStatus: accountStatus,
                    VerificationStatus: verificationStatus,
                    ServiceTypes: selectedServiceTypes
                };

                // Upload new profile image to Firebase Storage if selected
                if (newProfileImageFile) {
                    try {
                        const extension = newProfileImageFile.name.split('.').pop();
                        const storagePath = `contractors/${contractorId}/profile_${Date.now()}.${extension}`;
                        const storageRef = ref(storage, storagePath);
                        await uploadBytes(storageRef, newProfileImageFile);
                        const downloadUrl = await getDownloadURL(storageRef);
                        updateData.SubmittedSelfieUrl = downloadUrl;
                    } catch (imgErr) {
                        console.error("Error uploading profile image:", imgErr);
                        alert("Profile image upload failed. Other details will still be saved.");
                    }
                }

                await updateDoc(contractorDocRef, updateData);

                alert("Contractor profile updated.");
                window.location.href = "ContractorProfile.aspx?id=" + contractorId;
            } catch (err) {
                console.error("Error saving contractor:", err);
                alert("Failed to save contractor.");
            }
        };
    </script>

</asp:Content>

<%@ Page Title="Edit Admin" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="AdminEdit.aspx.cs" Inherits="AdminPage.AdminEdit" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Edit Admin
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Page content (hidden until data loaded) -->
    <div id="pageContent" class="hidden">

        <!-- Back link + heading -->
        <div class="flex items-center gap-3 mb-6">
            <a href="AdminManagement.aspx" class="text-gray-400 hover:text-white">
                <i data-lucide="arrow-left" class="w-5 h-5"></i>
            </a>
            <h1 class="text-3xl font-bold text-yellow-400">Edit Admin</h1>
        </div>

        <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8">

            <!-- Profile Picture Section -->
            <div class="flex flex-col items-center mb-8">
                <div class="relative">
                    <div class="w-28 h-28 rounded-full bg-[#333] border-2 border-[#555] flex items-center justify-center overflow-hidden">
                        <img id="profilePic" src="" alt=""
                             class="w-full h-full object-cover hidden" />
                        <i data-lucide="user" class="w-12 h-12 text-gray-500" id="profilePlaceholder"></i>
                    </div>
                    <label for="picUpload"
                           class="absolute bottom-0 right-0 bg-yellow-500 hover:bg-yellow-600 text-black rounded-full w-8 h-8 flex items-center justify-center cursor-pointer shadow-lg">
                        <i data-lucide="camera" class="w-4 h-4"></i>
                    </label>
                    <input type="file" id="picUpload" accept="image/*" class="hidden" />
                </div>
                <p id="adminNameDisplay" class="mt-3 text-lg font-semibold text-white"></p>
            </div>

            <!-- 2-Column Form (ASP.NET server controls) -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

                <div>
                    <label class="block text-sm text-gray-400 mb-1">Full Name</label>
                    <asp:TextBox ID="txtAdminName" runat="server"
                        CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2.5 px-4 text-sm text-white focus:border-yellow-500 outline-none" />
                </div>

                <div>
                    <label class="block text-sm text-gray-400 mb-1">Email Address</label>
                    <asp:TextBox ID="txtAdminEmail" runat="server" TextMode="Email"
                        CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2.5 px-4 text-sm text-white focus:border-yellow-500 outline-none" />
                </div>

                <div>
                    <label class="block text-sm text-gray-400 mb-1">Phone Number</label>
                    <asp:TextBox ID="txtAdminPhone" runat="server"
                        CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2.5 px-4 text-sm text-white focus:border-yellow-500 outline-none" />
                </div>

                <div>
                    <label class="block text-sm text-gray-400 mb-1">IC Number</label>
                    <asp:TextBox ID="txtAdminIC" runat="server"
                        CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2.5 px-4 text-sm text-white focus:border-yellow-500 outline-none" />
                </div>

                <div>
                    <label class="block text-sm text-gray-400 mb-1">Account Status</label>
                    <asp:DropDownList ID="ddlAdminStatus" runat="server"
                        CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2.5 px-4 text-sm text-white focus:border-yellow-500 outline-none">
                        <asp:ListItem Value="Active" Text="Active" />
                        <asp:ListItem Value="Deactivated" Text="Deactivated" />
                    </asp:DropDownList>
                </div>
            </div>

            <!-- Action buttons -->
            <div class="flex justify-end gap-3 mt-8">
                <a href="AdminManagement.aspx"
                   class="px-6 py-2.5 rounded-lg bg-gray-600 text-white hover:bg-gray-500 text-sm">
                    Cancel
                </a>
                <button type="button" id="btnSave"
                        class="px-6 py-2.5 rounded-lg bg-yellow-500 text-black font-semibold hover:bg-yellow-600 text-sm flex items-center gap-2">
                    <svg id="saveSpinner" class="hidden animate-spin h-4 w-4 text-black" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
                    </svg>
                    Save Changes
                </button>
            </div>

        </div>
    </div>

    <!-- Loading state -->
    <div id="loadingState" class="text-center py-20 text-gray-400">Loading admin data...</div>

    <!-- Error state -->
    <div id="errorState" class="hidden text-center py-20">
        <p class="text-red-400 mb-4">Admin not found or an error occurred.</p>
        <a href="AdminManagement.aspx" class="text-blue-400 hover:underline">Back to Admin Management</a>
    </div>

    <script type="module">
        // ── IMPORTS (read-only Firestore + Cloud Functions + Storage) ──
        import {
            collection,
            query,
            where,
            getDocs
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        import { getAuth } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
        import { getFunctions, httpsCallable } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-functions.js";

        import {
            getStorage,
            ref,
            uploadBytes,
            getDownloadURL
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-storage.js";

        // ── ASP.NET ClientID references (bulletproof selectors) ──
        const elName   = document.getElementById('<%= txtAdminName.ClientID %>');
        const elEmail  = document.getElementById('<%= txtAdminEmail.ClientID %>');
        const elPhone  = document.getElementById('<%= txtAdminPhone.ClientID %>');
        const elIC     = document.getElementById('<%= txtAdminIC.ClientID %>');
        const elStatus = document.getElementById('<%= ddlAdminStatus.ClientID %>');
        const elBtn    = document.getElementById('btnSave');
        const elSpin   = document.getElementById('saveSpinner');

        let currentData = null;
        let pendingFile = null;
        let originalEmail = "";

        document.addEventListener("firebase-auth-ready", () => {
            loadAdmin();

            // Save button — single async handler, no wrappers
            elBtn.addEventListener("click", handleSave);

            // File picker — store file for later, show preview
            document.getElementById("picUpload").addEventListener("change", (e) => {
                const file = e.target.files[0];
                if (!file) return;
                pendingFile = file;
                const img = document.getElementById("profilePic");
                img.src = URL.createObjectURL(file);
                img.classList.remove("hidden");
                document.getElementById("profilePlaceholder").classList.add("hidden");
                console.log("Picture selected, pending upload:", file.name);
            });
        });

        // ── LOAD ────────────────────────────────────────────────────
        async function loadAdmin() {
            const uid = new URLSearchParams(window.location.search).get("uid");

            if (!uid) { showError(); return; }

            try {
                const q = query(collection(db, "Admins"), where("uid", "==", uid));
                const snap = await getDocs(q);

                if (snap.empty) { showError(); return; }

                currentData = snap.docs[0].data();

                // Populate ASP.NET controls
                elName.value   = currentData.AdminName || "";
                elEmail.value  = currentData.AdminEmail || "";
                originalEmail  = currentData.AdminEmail || "";
                elPhone.value  = currentData.AdminPhoneNumber || "";
                elIC.value     = currentData.AdminIC || "";
                elStatus.value = currentData.AdminStatus || "Active";

                document.getElementById("adminNameDisplay").textContent = currentData.AdminName || "";

                // Profile picture
                if (currentData.AdminPicture) {
                    const img = document.getElementById("profilePic");
                    img.src = currentData.AdminPicture;
                    img.classList.remove("hidden");
                    document.getElementById("profilePlaceholder").classList.add("hidden");
                }

                document.getElementById("loadingState").classList.add("hidden");
                document.getElementById("pageContent").classList.remove("hidden");
                if (window.lucide) lucide.createIcons();

            } catch (err) {
                console.error("Error loading admin:", err);
                showError();
            }
        }

        function showError() {
            document.getElementById("loadingState").classList.add("hidden");
            document.getElementById("errorState").classList.remove("hidden");
        }

        // ══════════════════════════════════════════════════════════════
        // handleSave — single, flat, async function. No wrappers.
        //
        //   Step 1: Validate fields
        //   Step 2: If new picture selected → await upload → get URL
        //   Step 3: Build payload (with picture URL already resolved)
        //   Step 4: console.log the final payload
        //   Step 5: await Cloud Function call
        //   Step 6: Redirect
        //
        // Nothing runs after step 2 until the upload is done.
        // Nothing runs after step 5 until the function returns.
        // ══════════════════════════════════════════════════════════════
        async function handleSave() {

            // ── Step 1: Read & validate ──
            const targetUid = new URLSearchParams(window.location.search).get("uid");
            const nameVal   = (elName.value   || "").trim();
            const emailVal  = (elEmail.value  || "").trim();
            const phoneVal  = (elPhone.value  || "").trim();
            const icVal     = (elIC.value     || "").trim();
            const statusVal = (elStatus.value || "").trim();

            if (!targetUid)  { alert("Error: No admin UID found in the URL."); return; }
            if (!nameVal)    { alert("Full Name cannot be empty.");             return; }
            if (!emailVal)   { alert("Email Address cannot be empty.");         return; }
            if (!phoneVal)   { alert("Phone Number cannot be empty.");          return; }
            if (!icVal)      { alert("IC Number cannot be empty.");             return; }

            elBtn.disabled = true;
            elSpin.classList.remove("hidden");

            // ── Step 2: Upload picture if one was selected ──
            let pictureURL = currentData.AdminPicture || "";

            if (pendingFile) {
                console.log("Step 2: Uploading picture...", pendingFile.name);
                try {
                    const storage   = getStorage();
                    const storageRef = ref(storage, "profile_pictures/" + currentData.uid);

                    const uploadResult = await uploadBytes(storageRef, pendingFile);
                    console.log("Upload complete:", uploadResult.metadata.fullPath);

                    pictureURL = await getDownloadURL(storageRef);
                    console.log("Download URL obtained:", pictureURL);

                    pendingFile = null;
                } catch (uploadErr) {
                    console.error("Image upload FAILED:", uploadErr);
                    alert("Failed to upload profile picture. Save aborted — nothing was changed.");
                    elBtn.disabled = false;
                    elSpin.classList.add("hidden");
                    return;
                }
            }

            // ── Step 3: Build payload (picture URL is guaranteed resolved) ──
            const payload = {
                targetUid:        targetUid,
                AdminName:        nameVal,
                AdminEmail:       emailVal,
                AdminPhoneNumber: phoneVal,
                AdminIC:          icVal,
                AdminStatus:      statusVal,
                AdminPicture:     pictureURL
            };

            // ── Step 4: Log final data ──
            console.log("Final data to save:", JSON.stringify(payload, null, 2));

            // ── Step 5: Call Cloud Function ──
            try {
                const functions = getFunctions(undefined, "asia-southeast1");
                const updateAdminProfile = httpsCallable(functions, "updateAdminProfile");

                const result = await updateAdminProfile(payload);
                console.log("Cloud Function returned:", result);

                // ── Step 6: Redirect ──
                const auth = getAuth();
                const isSelf = (targetUid === auth.currentUser?.uid);
                const emailChanged = (emailVal !== originalEmail);

                if (isSelf && emailChanged) {
                    alert("Your profile has been updated successfully! For security, you will now be logged out. Please log in with your new email.");
                    await auth.signOut();
                    window.location.href = "Login.aspx?action=logout";
                } else {
                    alert("Profile updated successfully!");
                    window.location.href = "AdminManagement.aspx";
                }
            } catch (err) {
                console.error("Cloud Function error:", err);
                alert(err.message || "Failed to update admin. Check the F12 console.");
                elBtn.disabled = false;
                elSpin.classList.add("hidden");
            }
        }
    </script>

</asp:Content>

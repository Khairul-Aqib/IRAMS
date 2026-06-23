<%@ Page Title="Edit User" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="UserEdit.aspx.cs" Inherits="AdminPage.UserEdit" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Edit User
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Users Management &gt; Edit Profile</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8 max-w-4xl">

        <!-- Avatar section -->
        <div class="flex justify-center mb-6">
            <div class="relative">
                <div class="w-28 h-28 rounded-full bg-gray-600 overflow-hidden">
                    <img id="editProfileImage"
                         src="https://via.placeholder.com/150"
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
                <asp:TextBox ID="txtFullName" runat="server" ClientIDMode="Static"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Email Address</label>
                <asp:TextBox ID="txtEmail" runat="server" ClientIDMode="Static"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Phone Number</label>
                <asp:TextBox ID="txtPhone" runat="server" ClientIDMode="Static"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />
            </div>

            <div>
                <label class="block text-sm font-semibold mb-1">Emergency Contact Name</label>
                <asp:TextBox ID="txtEmergencyName" runat="server" ClientIDMode="Static"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Emergency Contact Phone</label>
                <asp:TextBox ID="txtEmergencyPhone" runat="server" ClientIDMode="Static"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />

                <label class="block text-sm font-semibold mt-4 mb-1">Account Status</label>
                <asp:DropDownList ID="ddlStatus" runat="server" ClientIDMode="Static"
                    CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4">
                    <asp:ListItem Text="Active" Value="Active" />
                    <asp:ListItem Text="Suspended" Value="Suspended" />
                </asp:DropDownList>
            </div>
        </div>

        <div class="flex gap-4 mt-8">
            <asp:Button ID="btnSave" runat="server" Text="Save"
                OnClientClick="saveUserProfile(); return false;"
                CssClass="bg-yellow-500 hover:bg-yellow-600 text-black font-semibold px-8 py-2 rounded-full cursor-pointer" />

            <asp:HyperLink ID="lnkCancel" runat="server" ClientIDMode="Static" NavigateUrl="~/Users.aspx"
                CssClass="bg-gray-500 hover:bg-gray-600 text-white font-semibold px-8 py-2 rounded-full">
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
            query,
            where,
            limit,
            getDocs
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        import {
            getStorage, ref as storageRef, uploadBytes, getDownloadURL
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-storage.js";

        let _storage = null;
        function getStorageLazy() {
            if (!_storage) _storage = getStorage();
            return _storage;
        }

        let urlIdParam = null;     // raw value from ?id= (auth UID per new architecture)
        let userDocId = null;      // resolved Users/{docId} (e.g. "U001")
        let userDocRef = null;
        let selectedImageFile = null;

        // Resolve the Users document. Per the new ID architecture, the URL `id` is
        // the Firebase Auth UID, and the U*** document is found via the `authUid` field.
        // Falls back to a direct doc lookup so legacy callers still work.
        async function resolveUserDoc(idParam) {
            const q = query(
                collection(db, "Users"),
                where("authUid", "==", idParam),
                limit(1)
            );
            const qSnap = await getDocs(q);
            if (!qSnap.empty) {
                const d = qSnap.docs[0];
                return { id: d.id, data: d.data() };
            }
            const directRef = doc(db, "Users", idParam);
            const directSnap = await getDoc(directRef);
            if (directSnap.exists()) {
                return { id: directSnap.id, data: directSnap.data() };
            }
            return null;
        }

        // Wait until Firebase (db, auth) is ready (from Site1.Master)
        document.addEventListener("firebase-auth-ready", async () => {
            const params = new URLSearchParams(window.location.search);
            urlIdParam = params.get("id");

            if (!urlIdParam) {
                alert("No user id.");
                window.location.href = "Users.aspx";
                return;
            }

            const resolved = await resolveUserDoc(urlIdParam);
            if (!resolved) {
                alert("User not found.");
                window.location.href = "Users.aspx";
                return;
            }

            userDocId = resolved.id;
            userDocRef = doc(db, "Users", userDocId);

            // Load user data into the form
            await loadUserForEdit(resolved.data);

            // Set Cancel link to go back to profile for this user
            const cancelLink = document.getElementById("lnkCancel");
            if (cancelLink) {
                cancelLink.href = "UserProfile.aspx?id=" + urlIdParam;
            }

            // Handle profile image selection — preview only.
            // The actual upload to Firebase Storage happens on Save.
            const fileInput = document.getElementById("fileProfileImage");
            if (fileInput) {
                fileInput.addEventListener("change", (e) => {
                    const file = e.target.files[0];
                    if (!file) return;

                    selectedImageFile = file;
                    document.getElementById("editProfileImage").src = URL.createObjectURL(file);
                });
            }
        });

        async function loadUserForEdit(preloaded) {
            try {
                let u = preloaded;
                if (!u) {
                    const snap = await getDoc(userDocRef);
                    if (!snap.exists()) {
                        alert("User not found.");
                        window.location.href = "Users.aspx";
                        return;
                    }
                    u = snap.data();
                }
                console.log("Editing user:", u);

                // Field-name variants: the mobile user app uses camelCase
                // (fullName, email, phone, ...) while older admin-side writes
                // used PascalCase. Try each order so the form populates for
                // either data source.
                const fullName       = u.fullName || u.FullName || "";
                const email          = u.email || u.Email || "";
                const phone          = u.phone || u.PhoneNumber || u.Phone || "";
                // Read camelCase (mobile-app source of truth) first, fall back to
                // PascalCase / legacy variants — keeps the edit form in sync with
                // changes the user made in the mobile app.
                const emergencyName  = u.emergencyContactName || u.emergencyName || u.EmergencyName || "";
                const emergencyPhone = u.emergencyContactPhone || u.emergencyPhone || u.EmergencyPhone || "";
                const status         = u.Status || u.AccountStatus || u.accountStatus || "Active";
                const profileImage   = u.profileImageUrl || "";

                // Fill form fields
                document.getElementById("txtFullName").value = fullName;
                document.getElementById("txtEmail").value = email;
                document.getElementById("txtPhone").value = phone;
                document.getElementById("txtEmergencyName").value = emergencyName;
                document.getElementById("txtEmergencyPhone").value = emergencyPhone;
                document.getElementById("ddlStatus").value = status;

                // Profile image: full URLs (mobile app's Storage download URL or
                // any external host) used as-is; bare file names are served
                // from the admin's local images/ folder.
                if (profileImage) {
                    let imageSrc = profileImage;
                    if (!imageSrc.startsWith("http://") && !imageSrc.startsWith("https://") && !imageSrc.startsWith("data:")) {
                        imageSrc = imageSrc.replace("~/", "");
                        if (!imageSrc.startsWith("images/")) imageSrc = "images/" + imageSrc;
                    }
                    const imgEl = document.getElementById("editProfileImage");
                    imgEl.src = imageSrc;
                    imgEl.onerror = () => { imgEl.onerror = null; imgEl.src = "images/default-avatar.png"; };
                }
            } catch (err) {
                console.error("Error loading user for edit:", err);
                alert("Failed to load user data.");
            }
        }

        // Save button handler (called from OnClientClick)
        window.saveUserProfile = async function () {
            if (!userDocRef) return;

            const saveBtn = document.getElementById("<%= btnSave.ClientID %>");
            const originalBtnText = saveBtn ? saveBtn.value : null;

            const fullName = document.getElementById("txtFullName").value.trim();
            const email = document.getElementById("txtEmail").value.trim();
            const phone = document.getElementById("txtPhone").value.trim();
            const emergencyName = document.getElementById("txtEmergencyName").value.trim();
            const emergencyPhone = document.getElementById("txtEmergencyPhone").value.trim();
            const status = document.getElementById("ddlStatus").value;

            if (!fullName || !email) {
                alert("Full Name and Email are required.");
                return;
            }

            try {
                if (saveBtn) {
                    saveBtn.disabled = true;
                    saveBtn.value = "Saving...";
                }

                // Write both casings so the mobile app (camelCase) and the
                // admin app (PascalCase) both see the updated values.
                const updateData = {
                    fullName: fullName,
                    FullName: fullName,
                    email: email,
                    Email: email,
                    phone: phone,
                    PhoneNumber: phone,
                    EmergencyName: emergencyName,
                    emergencyContactName: emergencyName,
                    EmergencyPhone: emergencyPhone,
                    emergencyContactPhone: emergencyPhone,
                    Status: status,
                    AccountStatus: status
                };

                // If user selected a new image, upload it directly to Firebase Storage
                // from the browser (same pattern as ServiceAdd.aspx). Triple-write the
                // resulting download URL so the Flutter user app and both casings of
                // the admin UI all stay in sync.
                if (selectedImageFile) {
                    if (saveBtn) saveBtn.value = "Uploading...";

                    const ext = (selectedImageFile.name.split(".").pop() || "jpg").toLowerCase();
                    const path = `profile_pictures/${userDocId}.${ext}`;
                    const fileRef = storageRef(getStorageLazy(), path);
                    await uploadBytes(fileRef, selectedImageFile, { contentType: selectedImageFile.type });
                    const downloadUrl = await getDownloadURL(fileRef);

                    // Single canonical field — matches the Flutter user app
                    // (user_profile.dart writes profileImageUrl on Users/{U***}).
                    updateData.profileImageUrl = downloadUrl;
                }

                await updateDoc(userDocRef, updateData);
                alert("User profile updated successfully!");
                window.location.href = "UserProfile.aspx?id=" + urlIdParam;

            } catch (err) {
                console.error("Error saving user:", err);
                alert("Failed to save user: " + (err && err.message ? err.message : err));
                if (saveBtn) {
                    saveBtn.disabled = false;
                    saveBtn.value = originalBtnText || "Save";
                }
            }
        };
    </script>

</asp:Content>

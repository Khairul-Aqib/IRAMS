<%@ Page Title="Add New Service" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="ServiceAdd.aspx.cs" Inherits="AdminPage.ServiceAdd" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Add New Service
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Services Management &gt; Add New Service</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8 max-w-3xl">

        <!-- Service Name -->
        <div class="mb-5">
            <label class="block text-sm font-semibold mb-1">Service Name</label>
            <asp:TextBox ID="txtServiceName" runat="server"
                CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />
        </div>

        <!-- Base Price -->
        <div class="mb-5">
            <label class="block text-sm font-semibold mb-1">Base Price (RM)</label>
            <asp:TextBox ID="txtBasePrice" runat="server"
                CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />
        </div>

        <!-- Description -->
        <div class="mb-5">
            <label class="block text-sm font-semibold mb-1">Description</label>
            <asp:TextBox ID="txtDescription" runat="server" TextMode="MultiLine" Rows="3" MaxLength="120"
                CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />
            <div class="flex justify-between items-center mt-1">
                <asp:RequiredFieldValidator ID="rfvDescription" runat="server"
                    ControlToValidate="txtDescription"
                    ErrorMessage="Description is required."
                    Display="Dynamic"
                    CssClass="text-red-500 text-xs" />
                <span id="charCount" class="text-xs text-gray-400 ml-auto">0/120</span>
            </div>
        </div>

        <!-- Service Icon -->
        <div class="mb-5">
            <label class="block text-sm font-semibold mb-2">Service Icon</label>

            <asp:TextBox ID="txtIconUrl" runat="server" CssClass="hidden" />

            <div class="flex items-center gap-4">
                <div class="w-24 h-24 rounded-lg bg-[#0d0d0d] border border-[#333] flex items-center justify-center overflow-hidden shrink-0">
                    <img id="iconPreview" alt="Icon preview" class="w-full h-full object-contain hidden" />
                    <span id="iconPlaceholder" class="text-xs text-gray-500">No icon</span>
                </div>
                <div>
                    <button type="button" id="btnUploadIcon"
                            class="bg-[#0d0d0d] border border-[#333] hover:bg-[#262626] px-4 py-2 rounded-lg text-sm cursor-pointer">
                        Upload Icon
                    </button>
                    <input id="iconFile" type="file" accept="image/*" class="hidden" />
                    <p class="text-xs text-gray-400 mt-2">
                        PNG / SVG / JPG. Uploaded to Firebase Storage on save.
                    </p>
                </div>
            </div>
        </div>

        <!-- Status -->
        <div class="mb-8">
            <label class="block text-sm font-semibold mb-2">Status</label>
            <asp:DropDownList ID="ddlStatus" runat="server"
                CssClass="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4">
                <asp:ListItem Text="Active" Value="Active" Selected="True" />
                <asp:ListItem Text="Inactive" Value="Inactive" />
            </asp:DropDownList>
        </div>

        <!-- Validation message -->
        <p id="validationMsg" class="text-red-500 text-sm mb-3 hidden"></p>

        <!-- Buttons -->
        <div class="flex gap-4">
            <asp:Button ID="btnSave" runat="server" Text="Save"
                UseSubmitBehavior="False"
                OnClientClick="saveService(); return false;"
                CssClass="bg-yellow-500 hover:bg-yellow-600 text-black font-semibold px-6 py-2 rounded-full" />

            <asp:HyperLink ID="lnkCancel" runat="server" NavigateUrl="~/Services.aspx"
                CssClass="bg-gray-500 hover:bg-gray-600 text-white font-semibold px-6 py-2 rounded-full">
                Cancel
            </asp:HyperLink>
        </div>

    </div>

    <script type="module">
        import {
            collection,
            getDocs,
            doc,
            setDoc
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        import {
            getStorage, ref as storageRef, uploadBytes, getDownloadURL
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-storage.js";

        let _storage = null;
        function getStorageLazy() {
            if (!_storage) _storage = getStorage();
            return _storage;
        }

        let selectedIconFile = null;

        // Helper: make a safe doc ID from the service name
        function makeDocIdFromName(name) {
            let slug = name
                .trim()
                .toLowerCase()
                .replace(/\s+/g, "-")        // spaces becomes dashes
                .replace(/[^a-z0-9\-]/g, ""); // remove the invalid chars

            if (!slug) {
                slug = "service-" + Date.now(); // fallback
            }
            return slug;
        }

        document.addEventListener("DOMContentLoaded", () => {
            const btn = document.getElementById("btnUploadIcon");
            const fileInput = document.getElementById("iconFile");
            const preview = document.getElementById("iconPreview");
            const placeholder = document.getElementById("iconPlaceholder");

            btn.addEventListener("click", () => fileInput.click());
            fileInput.addEventListener("change", (e) => {
                const file = e.target.files && e.target.files[0];
                if (!file) return;
                selectedIconFile = file;
                preview.src = URL.createObjectURL(file);
                preview.classList.remove("hidden");
                placeholder.classList.add("hidden");
            });

            const DESC_MAX = 120;
            const descEl = document.getElementById("<%= txtDescription.ClientID %>");
            const countEl = document.getElementById("charCount");
            function updateCharCount() {
                if (descEl.value.length > DESC_MAX) {
                    descEl.value = descEl.value.substring(0, DESC_MAX);
                }
                const len = descEl.value.length;
                countEl.textContent = len + "/" + DESC_MAX;
                if (len >= DESC_MAX) {
                    countEl.classList.remove("text-gray-400");
                    countEl.classList.add("text-red-500");
                } else {
                    countEl.classList.remove("text-red-500");
                    countEl.classList.add("text-gray-400");
                }
            }
            descEl.addEventListener("input", updateCharCount);
            updateCharCount();
        });

        window.saveService = async function () {
            console.log("[ServiceAdd] saveService invoked");

            const saveBtn = document.getElementById("<%= btnSave.ClientID %>");
            const originalBtnText = saveBtn ? saveBtn.value : null;

            try {
                const name = document.getElementById("<%= txtServiceName.ClientID %>").value.trim();
                const price = document.getElementById("<%= txtBasePrice.ClientID %>").value.trim();
                const desc  = document.getElementById("<%= txtDescription.ClientID %>").value.trim();
                const status = document.getElementById("<%= ddlStatus.ClientID %>").value;

                const msgEl = document.getElementById("validationMsg");
                if (typeof Page_ClientValidate === "function") {
                    Page_ClientValidate();
                }
                if (!name || !price || !desc) {
                    const missing = [];
                    if (!name) missing.push("Service Name");
                    if (!price) missing.push("Base Price");
                    if (!desc) missing.push("Description");
                    const text = "Please fill in: " + missing.join(", ") + ".";
                    if (msgEl) {
                        msgEl.textContent = text;
                        msgEl.classList.remove("hidden");
                    }
                    alert(text);
                    return;
                }
                if (msgEl) {
                    msgEl.textContent = "";
                    msgEl.classList.add("hidden");
                }

                if (saveBtn) {
                    saveBtn.disabled = true;
                    saveBtn.value = "Uploading...";
                }

                if (!window.db) {
                    throw new Error("Firestore is not initialized yet. Please refresh and try again.");
                }

                // Get all existing ServiceID values to generate next Sxxx
                console.log("[ServiceAdd] reading existing services...");
                const snap = await getDocs(collection(db, "Services"));
                let maxID = 0;

                snap.forEach(docSnap => {
                    const data = docSnap.data();
                    if (data.ServiceID) {
                        const num = parseInt(data.ServiceID.substring(1)); // For example "S005" then it means 5
                        if (!isNaN(num) && num > maxID) maxID = num;
                    }
                });

                // Generate next ServiceID like S001
                const nextID = maxID + 1;
                const serviceID = "S" + nextID.toString().padStart(3, "0");

                // Build a custom document ID based on the service name. The slugifier
                // strips spaces and special characters, so the Storage path it feeds
                // into below is always safe (e.g. "Battery Jump Start" -> "battery-jump-start").
                const docId = makeDocIdFromName(name);
                console.log("[ServiceAdd] computed docId =", docId, " serviceID =", serviceID);

                // Upload icon first (if one was selected) so we can persist its URL.
                // If no file was picked we skip Storage entirely — iconUrl stays "".
                let iconUrl = "";
                if (selectedIconFile) {
                    console.log("[ServiceAdd] uploading icon:", selectedIconFile.name, selectedIconFile.size, "bytes");
                    const path = `service_icons/${docId}.png`;
                    const fileRef = storageRef(getStorageLazy(), path);
                    await uploadBytes(fileRef, selectedIconFile);
                    iconUrl = await getDownloadURL(fileRef);
                    console.log("[ServiceAdd] icon uploaded; url =", iconUrl);
                } else {
                    console.log("[ServiceAdd] no icon selected; skipping upload");
                }

                // Create / overwrite that document with setDoc
                console.log("[ServiceAdd] writing Services/" + docId);
                await setDoc(doc(db, "Services", docId), {
                    ServiceID: serviceID,
                    ServiceName: name,
                    BasePrice: price,
                    Description: desc,
                    iconUrl: iconUrl,
                    Status: status,
                    CreatedAt: new Date()
                });

                alert("Service created successfully!");
                window.location.href = "Services.aspx";

            } catch (err) {
                console.error("[ServiceAdd] saveService failed:", err);
                alert("Error saving: " + (err && err.message ? err.message : err));

                if (saveBtn) {
                    saveBtn.disabled = false;
                    saveBtn.value = originalBtnText || "Save";
                }
            }
        };
    </script>

</asp:Content>

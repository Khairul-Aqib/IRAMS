<%@ Page Title="Edit Service" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="ServiceEdit.aspx.cs" Inherits="AdminPage.ServiceEdit" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Edit Service
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Services Management &gt; Edit Service</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-8 max-w-3xl">

        <div class="mb-5">
            <label class="block text-sm font-semibold mb-1">Service Name</label>
            <asp:TextBox ID="txtServiceName" runat="server"
                CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />
        </div>

        <div class="mb-5">
            <label class="block text-sm font-semibold mb-1">Base Price (RM)</label>
            <asp:TextBox ID="txtBasePrice" runat="server"
                CssClass="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4" />
        </div>

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
                        Pick a new image to replace the icon, or leave it as-is to keep the existing one.
                    </p>
                </div>
            </div>
        </div>

        <div class="mb-8">
            <label class="block text-sm font-semibold mb-2">Status</label>
            <asp:DropDownList ID="ddlStatus" runat="server"
                CssClass="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-4">
                <asp:ListItem Text="Active" Value="Active" />
                <asp:ListItem Text="Inactive" Value="Inactive" />
            </asp:DropDownList>
        </div>

        <div class="flex gap-4">
            <asp:Button ID="btnSave" runat="server" Text="Save"
                OnClientClick="updateService(); return false;"
                CssClass="bg-yellow-500 hover:bg-yellow-600 text-black font-semibold px-6 py-2 rounded-full" />

            <asp:HyperLink ID="lnkCancel" runat="server" NavigateUrl="~/Services.aspx"
                CssClass="bg-gray-500 hover:bg-gray-600 text-white font-semibold px-6 py-2 rounded-full">
                Cancel
            </asp:HyperLink>
        </div>

    </div>

    <script type="module">
        import {
            doc,
            getDoc,
            updateDoc
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        import {
            getStorage, ref as storageRef, uploadBytes, getDownloadURL
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-storage.js";

        let _storage = null;
        function getStorageLazy() {
            if (!_storage) _storage = getStorage();
            return _storage;
        }

        let serviceId = null;
        let selectedIconFile = null;

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

            const descEl = document.getElementById("<%= txtDescription.ClientID %>");
            descEl.addEventListener("input", window.updateCharCount);
            window.updateCharCount();
        });

        const DESC_MAX = 120;
        window.updateCharCount = function () {
            const descEl = document.getElementById("<%= txtDescription.ClientID %>");
            const countEl = document.getElementById("charCount");
            if (!descEl || !countEl) return;
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
        };

        document.addEventListener("firebase-auth-ready", async () => {
            // get ?id= from the query string
            const params = new URLSearchParams(window.location.search);
            serviceId = params.get("id");

            if (!serviceId) {
                alert("No service id provided.");
                window.location.href = "Services.aspx";
                return;
            }

            await loadService(serviceId);
        });

        async function loadService(id) {
            try {
                const docRef = doc(db, "Services", id);
                const snap = await getDoc(docRef);

                if (!snap.exists()) {
                    alert("Service not found.");
                    window.location.href = "Services.aspx";
                    return;
                }

                const data = snap.data();

                document.getElementById("<%= txtServiceName.ClientID %>").value = data.ServiceName || "";
                document.getElementById("<%= txtBasePrice.ClientID %>").value = data.BasePrice || "";
                document.getElementById("<%= txtDescription.ClientID %>").value = data.Description || "";
                document.getElementById("<%= txtIconUrl.ClientID %>").value = data.iconUrl || "";
                document.getElementById("<%= ddlStatus.ClientID %>").value = data.Status || "Active";

                if (typeof window.updateCharCount === "function") window.updateCharCount();

                // Show the existing icon in the preview if one is on file.
                if (data.iconUrl) {
                    const preview = document.getElementById("iconPreview");
                    const placeholder = document.getElementById("iconPlaceholder");
                    preview.src = data.iconUrl;
                    preview.classList.remove("hidden");
                    placeholder.classList.add("hidden");
                }

            } catch (err) {
                console.error("Error loading service:", err);
                alert("Failed to load service data.");
            }
        }

        window.updateService = async function () {
            if (!serviceId) return;

            const name = document.getElementById("<%= txtServiceName.ClientID %>").value.trim();
            const price = document.getElementById("<%= txtBasePrice.ClientID %>").value.trim();
            const desc = document.getElementById("<%= txtDescription.ClientID %>").value.trim();
            const status = document.getElementById("<%= ddlStatus.ClientID %>").value;
            const existingIconUrl = document.getElementById("<%= txtIconUrl.ClientID %>").value.trim();

            if (typeof Page_ClientValidate === "function") {
                Page_ClientValidate();
            }
            if (!name || !price || !desc) {
                const missing = [];
                if (!name) missing.push("Service Name");
                if (!price) missing.push("Base Price");
                if (!desc) missing.push("Description");
                alert("Please fill in: " + missing.join(", ") + ".");
                return;
            }

            try {
                // If the admin picked a new icon, upload it; otherwise keep the existing URL.
                let iconUrl = existingIconUrl;
                if (selectedIconFile) {
                    const path = `service_icons/${serviceId}.png`;
                    const fileRef = storageRef(getStorageLazy(), path);
                    await uploadBytes(fileRef, selectedIconFile);
                    iconUrl = await getDownloadURL(fileRef);
                }

                const docRef = doc(db, "Services", serviceId);
                await updateDoc(docRef, {
                    ServiceName: name,
                    BasePrice: price,
                    Description: desc,
                    iconUrl: iconUrl,
                    Status: status
                });

                alert("Service updated successfully.");
                window.location.href = "Services.aspx";
            } catch (err) {
                console.error("Error updating service:", err);
                alert("Failed to update service.");
            }
        };
    </script>

</asp:Content>

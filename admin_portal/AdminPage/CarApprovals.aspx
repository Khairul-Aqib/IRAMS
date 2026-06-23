<%@ Page Title="Car Registration Approvals" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="CarApprovals.aspx.cs" Inherits="AdminPage.CarApprovals" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Car Registration Approvals
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-8 text-yellow-400">Car Registration Approvals</h1>

    <!-- SUMMARY CARDS -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-[#1f1f1f] rounded-xl p-5 border border-[#333]">
            <p class="text-sm text-gray-400 mb-1">Pending Review</p>
            <p class="text-4xl font-bold text-yellow-400" id="pendingCount">0</p>
        </div>
        <div class="bg-[#1f1f1f] rounded-xl p-5 border border-[#333]">
            <p class="text-sm text-gray-400 mb-1">Approved (last 50)</p>
            <p class="text-4xl font-bold text-green-400" id="approvedCount">0</p>
        </div>
        <div class="bg-[#1f1f1f] rounded-xl p-5 border border-[#333]">
            <p class="text-sm text-gray-400 mb-1">Rejected (last 50)</p>
            <p class="text-4xl font-bold text-red-400" id="rejectedCount">0</p>
        </div>
    </div>

    <!-- PENDING TABLE -->
    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-4">
            <h2 class="text-xl font-semibold">Pending Registrations</h2>
            <div class="relative">
                <input id="approvalSearch"
                       type="text"
                       class="bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-10 text-sm w-80"
                       placeholder="Search plate, brand, or model" />
                <i data-lucide="search" class="absolute left-3 top-2.5 w-4 h-4 text-gray-400"></i>
            </div>
        </div>

        <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
                <thead>
                    <tr class="bg-[#262626] text-gray-300">
                        <th class="py-3 px-4 text-left">Number Plate</th>
                        <th class="py-3 px-4 text-left">Manual Brand</th>
                        <th class="py-3 px-4 text-left">Manual Model</th>
                        <th class="py-3 px-4 text-left">Year</th>
                        <th class="py-3 px-4 text-left">Submitted</th>
                        <th class="py-3 px-4 text-left">Actions</th>
                    </tr>
                </thead>
                <tbody id="approvalsTableBody">
                </tbody>
            </table>
        </div>
    </div>

    <!-- APPROVE MODAL -->
    <div id="approveModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6 w-full max-w-lg">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-yellow-400">Approve Car Registration</h3>
                <button type="button" id="btnCloseApprove"
                        class="text-gray-400 hover:text-white text-2xl leading-none cursor-pointer">&times;</button>
            </div>

            <div class="text-sm text-gray-300 mb-4 bg-[#0d0d0d] border border-[#333] rounded-lg p-3">
                <div><span class="text-gray-400">Plate:</span> <span id="amPlate" class="font-semibold"></span></div>
                <div><span class="text-gray-400">User submitted:</span> <span id="amManual" class="font-semibold"></span></div>
            </div>

            <label class="block text-sm font-semibold mb-1">Map to Brand</label>
            <select id="amBrandSelect"
                    class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 mb-2">
                <option value="">-- Select brand --</option>
                <option value="__new__">-- Add New --</option>
            </select>
            <input id="amNewBrand" type="text"
                   class="hidden w-full bg-[#0d0d0d] border border-yellow-500 rounded-lg py-2 px-3 mb-4"
                   placeholder="Enter new brand name (e.g. BMW)" />
            <div id="amBrandSpacer" class="mb-4"></div>

            <label class="block text-sm font-semibold mb-1">Map to Model</label>
            <select id="amModelSelect"
                    class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 mb-2"
                    disabled>
                <option value="">-- Select model --</option>
                <option value="__new__">-- Add New --</option>
            </select>
            <input id="amNewModel" type="text"
                   class="hidden w-full bg-[#0d0d0d] border border-yellow-500 rounded-lg py-2 px-3 mb-4"
                   placeholder="Enter new model name (e.g. M3)" />
            <div id="amModelSpacer" class="mb-4"></div>

            <p id="amError" class="text-red-400 text-xs mb-3 hidden"></p>

            <div class="flex justify-end gap-3">
                <button type="button" id="btnCancelApprove"
                        class="px-4 py-2 rounded-lg bg-gray-600 text-white hover:bg-gray-500">
                    Cancel
                </button>
                <button type="button" id="btnConfirmApprove"
                        class="px-4 py-2 rounded-lg bg-green-500 text-black font-semibold hover:bg-green-400">
                    Approve
                </button>
            </div>
        </div>
    </div>

    <!-- REJECT MODAL -->
    <div id="rejectModal"
         class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 hidden">
        <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] p-6 w-full max-w-md">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-red-400">Reject Registration</h3>
                <button type="button" id="btnCloseReject"
                        class="text-gray-400 hover:text-white text-2xl leading-none cursor-pointer">&times;</button>
            </div>

            <p class="text-sm text-gray-300 mb-3">
                Mark this registration as <span class="text-red-400 font-semibold">Rejected</span>?
                The record stays in the database for audit but is removed from the pending list.
            </p>

            <label class="block text-sm font-semibold mb-1">Reason (optional)</label>
            <textarea id="rmReason" rows="3"
                      class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 mb-4"
                      placeholder="e.g. unreadable plate, duplicate submission..."></textarea>

            <div class="flex justify-end gap-3">
                <button type="button" id="btnCancelReject"
                        class="px-4 py-2 rounded-lg bg-gray-600 text-white hover:bg-gray-500">
                    Cancel
                </button>
                <button type="button" id="btnConfirmReject"
                        class="px-4 py-2 rounded-lg bg-red-500 text-white hover:bg-red-400">
                    Reject
                </button>
            </div>
        </div>
    </div>

    <!-- TOAST -->
    <div id="toast"
         class="fixed bottom-6 right-6 z-50 hidden bg-[#1f1f1f] border border-[#333] rounded-xl shadow-lg px-4 py-3 text-sm">
        <span id="toastMsg"></span>
    </div>

    <script type="module">
        import {
            collection,
            query,
            where,
            getDocs,
            getDoc,
            onSnapshot,
            updateDoc,
            setDoc,
            doc,
            serverTimestamp,
            orderBy,
            limit,
            arrayUnion
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

        let pending = [];
        let brands = {};            // { "Toyota": ["Vios", "Hilux"], ... }
        let currentSearch = "";

        // Cars currently in modal context.
        let approveCarId = null;
        let rejectCarId = null;

        document.addEventListener("firebase-auth-ready", async () => {
            await loadBrands();          // dropdown source
            loadPending();               // live queue
            loadStatusCounts();          // approved/rejected summaries
            setupSearch();
            setupApproveModal();
            setupRejectModal();
        });

        // ── Pending list (Make == "Undefined") ──────────────────────────────
        function loadPending() {
            const tbody = document.getElementById("approvalsTableBody");
            tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>Loading...</td></tr>";

            // We exclude already-rejected records so the queue only shows
            // genuinely pending submissions.
            const q = query(
                collection(db, "CarDetails"),
                where("Make", "==", "Undefined")
            );

            onSnapshot(q, (snap) => {
                pending = [];
                snap.forEach(docSnap => {
                    const data = docSnap.data();
                    if ((data.Status || "").toLowerCase() === "rejected") return;
                    pending.push({ id: docSnap.id, ...data });
                });

                document.getElementById("pendingCount").textContent = pending.length;
                applyFilter();
            }, (err) => {
                console.error("Error loading pending registrations:", err);
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-red-400'>Failed to load registrations.</td></tr>";
            });
        }

        function applyFilter() {
            let list = pending.slice();

            if (currentSearch) {
                list = list.filter(c =>
                    (c.NumberPlate || "").toLowerCase().includes(currentSearch) ||
                    (c.ManualBrandName || "").toLowerCase().includes(currentSearch) ||
                    (c.ManualModelName || "").toLowerCase().includes(currentSearch)
                );
            }

            // Oldest first so the longest-waiting users get processed first.
            list.sort((a, b) => {
                const da = a.CreatedAt && a.CreatedAt.toDate ? a.CreatedAt.toDate() : new Date(0);
                const db2 = b.CreatedAt && b.CreatedAt.toDate ? b.CreatedAt.toDate() : new Date(0);
                return da - db2;
            });

            renderTable(list);
        }

        function renderTable(list) {
            const tbody = document.getElementById("approvalsTableBody");
            tbody.innerHTML = "";

            if (list.length === 0) {
                tbody.innerHTML = "<tr><td colspan='6' class='py-4 px-4 text-center text-gray-400'>No pending registrations.</td></tr>";
                return;
            }

            for (const c of list) {
                const tr = document.createElement("tr");
                tr.className = "border-b border-[#333] hover:bg-[#262626]";

                let submitted = "N/A";
                if (c.CreatedAt && c.CreatedAt.toDate) {
                    submitted = c.CreatedAt.toDate().toLocaleString('en-GB', {
                        day: '2-digit', month: '2-digit', year: 'numeric',
                        hour: '2-digit', minute: '2-digit'
                    });
                }

                tr.innerHTML = `
                    <td class="py-3 px-4 font-semibold">${escapeHtml(c.NumberPlate || "-")}</td>
                    <td class="py-3 px-4">${escapeHtml(c.ManualBrandName || "-")}</td>
                    <td class="py-3 px-4">${escapeHtml(c.ManualModelName || "-")}</td>
                    <td class="py-3 px-4">${escapeHtml(c.Year || "-")}</td>
                    <td class="py-3 px-4 text-gray-400">${submitted}</td>
                    <td class="py-3 px-4">
                        <button type="button"
                                class="approve-btn px-3 py-1.5 rounded-lg bg-green-500 text-black text-xs font-semibold hover:bg-green-400 mr-2"
                                data-id="${c.id}">
                            Approve
                        </button>
                        <button type="button"
                                class="reject-btn px-3 py-1.5 rounded-lg bg-red-500 text-white text-xs font-semibold hover:bg-red-400"
                                data-id="${c.id}">
                            Reject
                        </button>
                    </td>
                `;
                tbody.appendChild(tr);
            }

            tbody.querySelectorAll(".approve-btn").forEach(btn => {
                btn.addEventListener("click", () => openApproveModal(btn.dataset.id));
            });
            tbody.querySelectorAll(".reject-btn").forEach(btn => {
                btn.addEventListener("click", () => openRejectModal(btn.dataset.id));
            });
        }

        function setupSearch() {
            const input = document.getElementById("approvalSearch");
            input.addEventListener("input", () => {
                currentSearch = input.value.toLowerCase();
                applyFilter();
            });
        }

        // ── Brand catalog (CarBrands collection) ────────────────────────────
        async function loadBrands() {
            try {
                const snap = await getDocs(collection(db, "CarBrands"));
                brands = {};
                snap.forEach(d => {
                    const data = d.data() || {};
                    const types = Array.isArray(data.CarTypes) ? data.CarTypes : [];
                    brands[d.id] = types;
                });

                const select = document.getElementById("amBrandSelect");
                Object.keys(brands).sort().forEach(b => {
                    const opt = document.createElement("option");
                    opt.value = b;
                    opt.textContent = b;
                    select.appendChild(opt);
                });
            } catch (err) {
                console.error("Error loading CarBrands:", err);
            }
        }

        // ── Approve modal ───────────────────────────────────────────────────
        function setupApproveModal() {
            document.getElementById("btnCloseApprove").addEventListener("click", closeApproveModal);
            document.getElementById("btnCancelApprove").addEventListener("click", closeApproveModal);

            const brandSelect = document.getElementById("amBrandSelect");
            const modelSelect = document.getElementById("amModelSelect");
            const newBrandInput = document.getElementById("amNewBrand");
            const newModelInput = document.getElementById("amNewModel");

            brandSelect.addEventListener("change", () => {
                const brand = brandSelect.value;
                rebuildModelOptions(brand);

                // Show "Add New" textbox for the brand only when explicitly chosen.
                if (brand === "__new__") {
                    newBrandInput.classList.remove("hidden");
                    // When adding a new brand there are no models yet — force the
                    // model picker into Add-New mode and let the admin type one.
                    modelSelect.value = "__new__";
                    modelSelect.disabled = false;
                    triggerModelChange();
                } else {
                    newBrandInput.classList.add("hidden");
                    newBrandInput.value = "";
                }
            });

            modelSelect.addEventListener("change", triggerModelChange);

            document.getElementById("btnConfirmApprove").addEventListener("click", confirmApprove);
        }

        function rebuildModelOptions(brand) {
            const modelSelect = document.getElementById("amModelSelect");
            modelSelect.innerHTML =
                '<option value="">-- Select model --</option>' +
                '<option value="__new__">-- Add New --</option>';

            if (brand && brand !== "__new__" && brands[brand]) {
                brands[brand].slice().sort().forEach(m => {
                    const opt = document.createElement("option");
                    opt.value = m;
                    opt.textContent = m;
                    modelSelect.appendChild(opt);
                });
            }

            // Disabled only when no brand has been chosen at all.
            modelSelect.disabled = !brand;
        }

        function triggerModelChange() {
            const modelSelect = document.getElementById("amModelSelect");
            const newModelInput = document.getElementById("amNewModel");
            if (modelSelect.value === "__new__") {
                newModelInput.classList.remove("hidden");
            } else {
                newModelInput.classList.add("hidden");
                newModelInput.value = "";
            }
        }

        function openApproveModal(carId) {
            const car = pending.find(c => c.id === carId);
            if (!car) return;

            approveCarId = carId;
            document.getElementById("amPlate").textContent = car.NumberPlate || "-";
            document.getElementById("amManual").textContent =
                `${car.ManualBrandName || "?"} ${car.ManualModelName || ""}`.trim();

            // Reset the Add-New inputs each time so a previous edit doesn't leak in.
            const brandSelect = document.getElementById("amBrandSelect");
            const modelSelect = document.getElementById("amModelSelect");
            const newBrandInput = document.getElementById("amNewBrand");
            const newModelInput = document.getElementById("amNewModel");
            newBrandInput.value = "";
            newModelInput.value = "";
            newBrandInput.classList.add("hidden");
            newModelInput.classList.add("hidden");

            // Pre-select the brand if the user-typed name happens to match a known one.
            const guessedBrand = matchBrandLoose(car.ManualBrandName);
            brandSelect.value = guessedBrand || "";
            brandSelect.dispatchEvent(new Event("change"));

            if (guessedBrand) {
                const guessedModel = matchModelLoose(guessedBrand, car.ManualModelName);
                if (guessedModel) {
                    modelSelect.value = guessedModel;
                    triggerModelChange();
                }
            }

            hideApproveError();
            document.getElementById("approveModal").classList.remove("hidden");
        }

        function closeApproveModal() {
            approveCarId = null;
            document.getElementById("approveModal").classList.add("hidden");
        }

        async function confirmApprove() {
            if (!approveCarId) return;

            const brandSel = document.getElementById("amBrandSelect").value;
            const modelSel = document.getElementById("amModelSelect").value;
            const newBrandRaw = document.getElementById("amNewBrand").value.trim();
            const newModelRaw = document.getElementById("amNewModel").value.trim();

            // Resolve the final brand/model values, validating Add-New text where used.
            let finalBrand = "";
            let isNewBrand = false;
            if (brandSel === "__new__") {
                if (!newBrandRaw) {
                    showApproveError("Please type the new brand name.");
                    return;
                }
                finalBrand = newBrandRaw;
                isNewBrand = true;
            } else if (brandSel) {
                finalBrand = brandSel;
            } else {
                showApproveError("Please pick a brand (or choose -- Add New --).");
                return;
            }

            let finalModel = "";
            let isNewModel = false;
            if (modelSel === "__new__") {
                if (!newModelRaw) {
                    showApproveError("Please type the new model name.");
                    return;
                }
                finalModel = newModelRaw;
                isNewModel = true;
            } else if (modelSel) {
                finalModel = modelSel;
            } else {
                showApproveError("Please pick a model (or choose -- Add New --).");
                return;
            }

            // Block exact-duplicate "new" entries that already exist in the catalog.
            if (isNewBrand && brands[finalBrand]) {
                showApproveError(`"${finalBrand}" already exists. Pick it from the list instead.`);
                return;
            }
            if (!isNewBrand && isNewModel && brands[finalBrand] &&
                brands[finalBrand].some(m => m.toLowerCase() === finalModel.toLowerCase())) {
                showApproveError(`"${finalModel}" already exists under ${finalBrand}.`);
                return;
            }

            const btn = document.getElementById("btnConfirmApprove");
            btn.disabled = true;
            btn.textContent = "Saving...";

            try {
                // ── 1. Make sure the brand doc exists, with the model in CarTypes ──
                const brandRef = doc(db, "CarBrands", finalBrand);

                if (isNewBrand) {
                    // New brand → create document with the chosen model as the first entry.
                    await setDoc(brandRef, {
                        CarTypes: [finalModel],
                        CreatedAt: serverTimestamp()
                    });
                } else if (isNewModel) {
                    // Existing brand, new model → append via arrayUnion (no duplicates).
                    await updateDoc(brandRef, {
                        CarTypes: arrayUnion(finalModel)
                    });
                }

                // Refresh the in-memory cache so the dropdown reflects the new entries
                // immediately if the admin keeps approving without reloading the page.
                if (isNewBrand) brands[finalBrand] = [finalModel];
                else if (isNewModel) {
                    brands[finalBrand] = brands[finalBrand] || [];
                    if (!brands[finalBrand].includes(finalModel)) brands[finalBrand].push(finalModel);
                }

                // ── 2. Stamp the resolved values back onto the CarDetails record ──
                await updateDoc(doc(db, "CarDetails", approveCarId), {
                    Make: finalBrand,
                    Model: finalModel,
                    ManualBrandName: "",
                    ManualModelName: "",
                    Status: "Approved",
                    ApprovedAt: serverTimestamp()
                });

                closeApproveModal();

                let msg = `Approved as ${finalBrand} ${finalModel}.`;
                if (isNewBrand) msg += " New brand added to catalog.";
                else if (isNewModel) msg += " New model added to catalog.";
                showToast(msg, "success");

                // Repopulate the brand dropdown in case a brand was added.
                if (isNewBrand) refreshBrandSelectOptions();
            } catch (err) {
                console.error("Error approving car:", err);
                showApproveError("Failed to save: " + (err.message || err));
            } finally {
                btn.disabled = false;
                btn.textContent = "Approve";
            }
        }

        function refreshBrandSelectOptions() {
            const select = document.getElementById("amBrandSelect");
            const previous = select.value;
            select.innerHTML =
                '<option value="">-- Select brand --</option>' +
                '<option value="__new__">-- Add New --</option>';
            Object.keys(brands).sort().forEach(b => {
                const opt = document.createElement("option");
                opt.value = b;
                opt.textContent = b;
                select.appendChild(opt);
            });
            // Best-effort restore; if the previous selection was "__new__" leave it blank.
            if (previous && previous !== "__new__" && brands[previous]) select.value = previous;
        }

        function showApproveError(msg) {
            const el = document.getElementById("amError");
            el.textContent = msg;
            el.classList.remove("hidden");
        }
        function hideApproveError() {
            document.getElementById("amError").classList.add("hidden");
        }

        // ── Reject modal ────────────────────────────────────────────────────
        function setupRejectModal() {
            document.getElementById("btnCloseReject").addEventListener("click", closeRejectModal);
            document.getElementById("btnCancelReject").addEventListener("click", closeRejectModal);
            document.getElementById("btnConfirmReject").addEventListener("click", confirmReject);
        }

        function openRejectModal(carId) {
            rejectCarId = carId;
            document.getElementById("rmReason").value = "";
            document.getElementById("rejectModal").classList.remove("hidden");
        }

        function closeRejectModal() {
            rejectCarId = null;
            document.getElementById("rejectModal").classList.add("hidden");
        }

        async function confirmReject() {
            if (!rejectCarId) return;

            const reason = document.getElementById("rmReason").value.trim();
            const btn = document.getElementById("btnConfirmReject");
            btn.disabled = true;
            btn.textContent = "Saving...";

            try {
                await updateDoc(doc(db, "CarDetails", rejectCarId), {
                    Status: "Rejected",
                    RejectedAt: serverTimestamp(),
                    RejectionReason: reason
                });

                closeRejectModal();
                showToast("Registration rejected.", "warn");
            } catch (err) {
                console.error("Error rejecting car:", err);
                alert("Failed to reject: " + (err.message || err));
            } finally {
                btn.disabled = false;
                btn.textContent = "Reject";
            }
        }

        // ── Approved/Rejected counters ──────────────────────────────────────
        function loadStatusCounts() {
            try {
                const approvedQ = query(
                    collection(db, "CarDetails"),
                    where("Status", "==", "Approved"),
                    orderBy("ApprovedAt", "desc"),
                    limit(50)
                );
                onSnapshot(approvedQ, (snap) => {
                    document.getElementById("approvedCount").textContent = snap.size;
                }, (err) => console.warn("Approved count query needs an index:", err));

                const rejectedQ = query(
                    collection(db, "CarDetails"),
                    where("Status", "==", "Rejected"),
                    orderBy("RejectedAt", "desc"),
                    limit(50)
                );
                onSnapshot(rejectedQ, (snap) => {
                    document.getElementById("rejectedCount").textContent = snap.size;
                }, (err) => console.warn("Rejected count query needs an index:", err));
            } catch (err) {
                console.error("Status counter setup failed:", err);
            }
        }

        // ── Helpers ─────────────────────────────────────────────────────────
        function matchBrandLoose(input) {
            if (!input) return null;
            const t = input.trim().toLowerCase();
            return Object.keys(brands).find(b => b.toLowerCase() === t) || null;
        }

        function matchModelLoose(brand, input) {
            if (!brand || !input || !brands[brand]) return null;
            const t = input.trim().toLowerCase();
            return brands[brand].find(m => m.toLowerCase() === t) || null;
        }

        function escapeHtml(s) {
            return String(s ?? "")
                .replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/"/g, "&quot;")
                .replace(/'/g, "&#39;");
        }

        let toastTimer = null;
        function showToast(message, kind) {
            const toast = document.getElementById("toast");
            const msg = document.getElementById("toastMsg");
            msg.textContent = message;

            // Reset border colour each call so success/warn don't bleed into the next toast.
            toast.classList.remove("border-green-500", "border-yellow-500", "border-red-500", "border-[#333]");
            if (kind === "success") toast.classList.add("border-green-500");
            else if (kind === "warn") toast.classList.add("border-yellow-500");
            else toast.classList.add("border-[#333]");

            toast.classList.remove("hidden");
            if (toastTimer) clearTimeout(toastTimer);
            toastTimer = setTimeout(() => toast.classList.add("hidden"), 3000);
        }
    </script>

</asp:Content>

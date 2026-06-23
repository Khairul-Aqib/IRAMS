<%@ Page Title="Support Chat" Language="C#" MasterPageFile="~/Site1.Master"
    AutoEventWireup="true" CodeBehind="SupportChat.aspx.cs" Inherits="AdminPage.SupportChat" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="server">
    Support Chat
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" runat="server">

    <h1 class="text-3xl font-bold mb-6 text-yellow-400">Support Chat</h1>

    <div class="bg-[#1f1f1f] rounded-2xl border border-[#333] overflow-hidden grid grid-cols-1 md:grid-cols-3 h-[calc(100vh-14rem)]">

        <!-- LEFT: conversation list -->
        <aside class="border-r border-[#333] flex flex-col min-h-0 overflow-hidden">
            <div class="h-20 px-4 py-4 flex items-center border-b border-[#333]">
                <input id="chatSearch" type="text"
                       class="w-full bg-[#0d0d0d] border border-[#333] rounded-lg py-2 px-3 text-sm"
                       placeholder="Search by user ID or name" />
            </div>
            <div id="conversationList" class="overflow-y-auto flex-1 min-h-0">
                <div class="py-6 px-4 text-center text-gray-400 text-sm">Loading conversations...</div>
            </div>
        </aside>

        <!-- RIGHT: thread + reply -->
        <section class="md:col-span-2 flex flex-col min-h-0 overflow-hidden">
            <header id="threadHeader" class="h-20 px-6 py-4 border-b border-[#333] flex items-center justify-between">
                <div>
                    <h2 id="threadTitle" class="text-lg font-semibold leading-tight">Select a conversation</h2>
                    <p id="threadSubtitle" class="text-xs text-gray-400 leading-tight">No user selected</p>
                </div>
            </header>

            <div id="threadMessages" class="flex-1 overflow-y-auto p-6 space-y-3 min-h-0">
                <div class="text-center text-gray-500 text-sm">Pick a conversation from the left to view messages.</div>
            </div>

            <div id="replyForm" class="flex items-center gap-2 p-2 bg-[#111b21] border-t border-[#333] w-full flex-shrink-0">
                <button id="attachBtn" type="button"
                        class="w-10 h-10 flex-shrink-0 rounded-full flex items-center justify-center text-gray-400 hover:text-white hover:bg-[#2a3942] disabled:opacity-50 disabled:cursor-not-allowed"
                        aria-label="Attach"
                        disabled>
                    <i data-lucide="plus" class="w-5 h-5"></i>
                </button>
                <input id="attachInput" type="file" class="hidden"
                       accept="image/*,application/pdf,.doc,.docx,.txt" />
                <textarea id="replyInput"
                          class="flex-grow rounded-full bg-[#2a3942] text-white px-5 py-2 h-10 text-sm resize-none leading-normal focus:outline-none disabled:opacity-50"
                          placeholder="Type a message..."
                          disabled></textarea>
                <button id="replySendBtn" type="button"
                        class="w-10 h-10 flex-shrink-0 rounded-full bg-yellow-500 hover:bg-yellow-600 flex items-center justify-center text-black disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                        aria-label="Send"
                        disabled>
                    <i data-lucide="send" class="w-5 h-5"></i>
                </button>
            </div>
        </section>
    </div>

    <script type="module">
        import {
            collection, doc, getDoc, setDoc,
            query, where, orderBy, limit,
            onSnapshot, addDoc, getDocs,
            serverTimestamp
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        import { getAuth } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
        import {
            getStorage, ref as storageRef, uploadBytes, getDownloadURL
        } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-storage.js";

        let _storage = null;
        function getStorageLazy() {
            if (!_storage) _storage = getStorage();
            return _storage;
        }

        // userId (U***) -> { lastMessage, lastUpdated }
        const threads = new Map();
        // userId -> resolved display name
        const userNameCache = new Map();
        // currently open thread's messages, keyed by message doc id
        let activeUserId = null;
        let activeMessages = [];
        let unsubscribeThreads = null;
        let unsubscribeMessages = null;
        let listSearch = "";

        function fmtTime(ts) {
            if (!ts) return "";
            const d = (typeof ts.toDate === "function") ? ts.toDate() : new Date(ts);
            if (isNaN(d.getTime())) return "";
            const now = new Date();
            const sameDay = d.toDateString() === now.toDateString();
            const hh = String(d.getHours()).padStart(2, "0");
            const mm = String(d.getMinutes()).padStart(2, "0");
            if (sameDay) return `${hh}:${mm}`;
            const dd = String(d.getDate()).padStart(2, "0");
            const mo = String(d.getMonth() + 1).padStart(2, "0");
            return `${dd}/${mo} ${hh}:${mm}`;
        }

        function escapeHtml(s) {
            return String(s ?? "")
                .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
        }

        async function resolveUserName(friendlyId) {
            if (!friendlyId) return "Unknown";
            if (userNameCache.has(friendlyId)) return userNameCache.get(friendlyId);

            const prefix = friendlyId.charAt(0).toUpperCase();

            try {
                if (prefix === "C") {
                    // Contractor lookup — Contractor docs are keyed by friendly C*** id.
                    const directSnap = await getDoc(doc(db, "Contractor", friendlyId));
                    if (directSnap.exists()) {
                        const d = directSnap.data();
                        const name = (d.CompanyName || d.ContractorName || d.FullName || friendlyId).toString().trim();
                        userNameCache.set(friendlyId, name || friendlyId);
                        return name || friendlyId;
                    }
                } else {
                    // Default to Users (covers U*** and any legacy ids).
                    const directSnap = await getDoc(doc(db, "Users", friendlyId));
                    if (directSnap.exists()) {
                        const d = directSnap.data();
                        const name = (d.FullName || d.fullName || friendlyId).toString().trim();
                        userNameCache.set(friendlyId, name || friendlyId);
                        return name || friendlyId;
                    }
                    const q = query(
                        collection(db, "Users"),
                        where("UserID", "==", friendlyId),
                        limit(1)
                    );
                    const qSnap = await getDocs(q);
                    if (!qSnap.empty) {
                        const d = qSnap.docs[0].data();
                        const name = (d.FullName || d.fullName || friendlyId).toString().trim();
                        userNameCache.set(friendlyId, name || friendlyId);
                        return name || friendlyId;
                    }
                }
            } catch (e) {
                console.warn("Name lookup failed for", friendlyId, e);
            }
            userNameCache.set(friendlyId, friendlyId);
            return friendlyId;
        }

        // Subscribe to the SupportChats parent collection. Each document is a
        // thread keyed by friendly U*** id and carries { userId, lastMessage, lastUpdated }.
        function startThreadListener() {
            if (unsubscribeThreads) unsubscribeThreads();

            const authUid = getAuth().currentUser?.uid;
            console.log("[SupportChat] starting thread listener; auth uid =", authUid);
            if (!authUid) {
                console.warn("[SupportChat] no auth uid — Firestore reads will be rejected. Check that Anonymous Auth is enabled in Firebase Console.");
            }

            unsubscribeThreads = onSnapshot(
                collection(db, "SupportChats"),
                async (snap) => {
                    console.log("[SupportChat] snapshot fired; size =", snap.size);
                    threads.clear();
                    snap.forEach(docSnap => {
                        const d = docSnap.data() || {};
                        const uid = d.userId || docSnap.id;
                        threads.set(uid, {
                            lastMessage: d.lastMessage || "",
                            lastUpdated: d.lastUpdated || null
                        });

                        // Prime the name cache from any name fields the parent
                        // thread doc already carries — saves a Firestore read.
                        const inlineName = (d.ContractorName || d.contractorName || d.CompanyName || d.FullName || d.fullName || "")
                            .toString()
                            .trim();
                        if (inlineName) {
                            userNameCache.set(uid, inlineName);
                        }
                    });
                    await renderConversationList();
                },
                (err) => {
                    console.error("SupportChats listener error:", err);
                    document.getElementById("conversationList").innerHTML =
                        "<div class='py-6 px-4 text-center text-red-400 text-sm'>Failed to load conversations.</div>";
                }
            );
        }

        function renderConversationList() {
            const wrap = document.getElementById("conversationList");

            const entries = [...threads.entries()].sort((a, b) => {
                const ta = a[1].lastUpdated?.toMillis ? a[1].lastUpdated.toMillis() : 0;
                const tb = b[1].lastUpdated?.toMillis ? b[1].lastUpdated.toMillis() : 0;
                return tb - ta;
            });

            const filtered = entries.filter(([uid]) => {
                if (!listSearch) return true;
                const name = (userNameCache.get(uid) || "").toLowerCase();
                return uid.toLowerCase().includes(listSearch) || name.includes(listSearch);
            });

            if (filtered.length === 0) {
                wrap.innerHTML = "<div class='py-6 px-4 text-center text-gray-400 text-sm'>No conversations.</div>";
                return;
            }

            // Paint immediately using cached names where available, falling back
            // to the friendly U-id. Names that aren't cached yet are resolved in
            // the background and patched into the DOM as they arrive.
            wrap.innerHTML = filtered.map(([uid, entry]) => {
                const name = userNameCache.get(uid) || uid;
                const isActive = uid === activeUserId;
                const bg = isActive ? "bg-[#262626]" : "hover:bg-[#222]";
                const preview = escapeHtml(entry.lastMessage).slice(0, 60);
                return `
                    <button type="button"
                            data-uid="${escapeHtml(uid)}"
                            class="conv-item w-full text-left px-4 py-3 border-b border-[#2a2a2a] ${bg} cursor-pointer">
                        <div class="flex items-center justify-between">
                            <span class="conv-name font-semibold text-sm" data-uid="${escapeHtml(uid)}">${escapeHtml(name)}</span>
                            <span class="text-[11px] text-gray-500">${fmtTime(entry.lastUpdated)}</span>
                        </div>
                        <div class="text-xs text-gray-400 mt-1">${escapeHtml(uid)}</div>
                        <div class="text-xs text-gray-300 mt-1 truncate">${preview}</div>
                    </button>`;
            }).join("");

            wrap.querySelectorAll(".conv-item").forEach(btn => {
                btn.addEventListener("click", () => {
                    selectThread(btn.dataset.uid);
                });
            });

            for (const [uid] of filtered) {
                if (userNameCache.has(uid)) continue;
                resolveUserName(uid).then(name => {
                    const el = wrap.querySelector(`.conv-name[data-uid="${CSS.escape(uid)}"]`);
                    if (el && name && name !== uid) el.textContent = name;
                });
            }
        }

        // Open a thread: subscribe to its messages subcollection.
        function selectThread(uid) {
            activeUserId = uid;
            activeMessages = [];

            if (unsubscribeMessages) unsubscribeMessages();

            const messagesQ = query(
                collection(db, "SupportChats", uid, "messages"),
                orderBy("createdAt", "asc")
            );

            unsubscribeMessages = onSnapshot(
                messagesQ,
                (snap) => {
                    activeMessages = snap.docs.map(d => ({ id: d.id, ...d.data() }));
                    renderThread();
                },
                (err) => {
                    console.error("Messages listener error:", err);
                    document.getElementById("threadMessages").innerHTML =
                        "<div class='text-center text-red-400 text-sm'>Failed to load messages.</div>";
                }
            );

            renderConversationList();
        }

        async function renderThread() {
            if (!activeUserId) return;

            const headerTitle = document.getElementById("threadTitle");
            const headerSub = document.getElementById("threadSubtitle");
            const threadEl = document.getElementById("threadMessages");
            const replyInput = document.getElementById("replyInput");
            const replySendBtn = document.getElementById("replySendBtn");

            const name = await resolveUserName(activeUserId);
            headerTitle.textContent = name;
            headerSub.textContent = activeUserId;
            replyInput.disabled = false;
            replySendBtn.disabled = false;
            const attachBtn = document.getElementById("attachBtn");
            if (attachBtn) attachBtn.disabled = false;

            if (activeMessages.length === 0) {
                threadEl.innerHTML = "<div class='text-center text-gray-500 text-sm'>No messages yet.</div>";
                return;
            }

            threadEl.innerHTML = activeMessages.map(m => {
                const fromAdmin = m.isFromAdmin === true;
                const align = fromAdmin ? "justify-end" : "justify-start";
                const itemsAlign = fromAdmin ? "items-end" : "items-start";
                const bubble = fromAdmin
                    ? "bg-yellow-500 text-black rounded-tr-none"
                    : "bg-gray-700 text-white rounded-tl-none";
                const senderLabel = fromAdmin ? "Admin" : activeUserId;
                const text = m.text ?? m.Text ?? "";
                const ts = m.createdAt ?? m.CreatedAt ?? null;
                const timeText = fmtTime(ts);
                const meta = timeText
                    ? `${escapeHtml(senderLabel)} - ${escapeHtml(timeText)}`
                    : escapeHtml(senderLabel);

                const url = m.attachmentUrl || m.AttachmentUrl || "";
                const aType = m.attachmentType || m.AttachmentType || "";
                const aName = m.attachmentName || m.AttachmentName || "attachment";
                let body = "";
                if (url) {
                    if (aType.startsWith("image/")) {
                        body += `<a href="${escapeHtml(url)}" target="_blank" rel="noopener"><img src="${escapeHtml(url)}" alt="${escapeHtml(aName)}" class="max-w-full max-h-64 rounded-lg block" /></a>`;
                    } else {
                        body += `<a href="${escapeHtml(url)}" target="_blank" rel="noopener" class="underline break-all">${escapeHtml(aName)}</a>`;
                    }
                    if (text.trim()) body += `<div class="mt-1">${escapeHtml(text.trim())}</div>`;
                } else {
                    body = escapeHtml(text.trim());
                }

                return `<div class="flex w-full ${align}"><div class="flex flex-col ${itemsAlign} max-w-[75%]"><div class="${bubble} w-fit max-w-full rounded-2xl px-3 py-1 text-sm text-left leading-snug whitespace-pre-wrap break-words">${body}</div><div class="text-xs text-gray-500 mt-1">${meta}</div></div></div>`;
            }).join("");

            threadEl.scrollTop = threadEl.scrollHeight;
        }

        async function sendReply() {
            const input = document.getElementById("replyInput");
            const btn = document.getElementById("replySendBtn");
            const text = input.value.trim();
            if (!text || !activeUserId) return;

            btn.disabled = true;
            try {
                const adminUid = getAuth().currentUser?.uid || "admin";

                // 1) Append the message to the nested subcollection.
                await addDoc(
                    collection(db, "SupportChats", activeUserId, "messages"),
                    {
                        text: text,
                        senderId: adminUid,
                        isFromAdmin: true,
                        createdAt: serverTimestamp()
                    }
                );

                // 2) Update the parent thread doc so the user app's inbox
                //    picks up the activity. setDoc with merge:true creates
                //    the parent if it somehow doesn't exist yet.
                await setDoc(
                    doc(db, "SupportChats", activeUserId),
                    {
                        userId: activeUserId,
                        lastMessage: text.slice(0, 80),
                        lastUpdated: serverTimestamp()
                    },
                    { merge: true }
                );

                input.value = "";
            } catch (err) {
                console.error("Failed to send reply:", err);
                alert("Failed to send reply. Check console for details.");
            } finally {
                btn.disabled = false;
                input.focus();
            }
        }

        function setupReply() {
            const input = document.getElementById("replyInput");
            const btn = document.getElementById("replySendBtn");
            btn.addEventListener("click", sendReply);
            input.addEventListener("keydown", (e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                    e.preventDefault();
                    sendReply();
                }
            });
        }

        async function sendAttachment(file) {
            if (!file || !activeUserId) return;

            const attachBtn = document.getElementById("attachBtn");
            attachBtn.disabled = true;
            try {
                const adminUid = getAuth().currentUser?.uid || "admin";
                const path = `support_chat_attachments/${activeUserId}/${Date.now()}_${file.name}`;
                const fileRef = storageRef(getStorageLazy(), path);
                await uploadBytes(fileRef, file);
                const url = await getDownloadURL(fileRef);
                const isImage = (file.type || "").startsWith("image/");

                await addDoc(
                    collection(db, "SupportChats", activeUserId, "messages"),
                    {
                        text: "",
                        attachmentUrl: url,
                        attachmentName: file.name,
                        attachmentType: file.type || "application/octet-stream",
                        senderId: adminUid,
                        isFromAdmin: true,
                        createdAt: serverTimestamp()
                    }
                );

                await setDoc(
                    doc(db, "SupportChats", activeUserId),
                    {
                        userId: activeUserId,
                        lastMessage: isImage ? "[Image]" : `[File] ${file.name}`,
                        lastUpdated: serverTimestamp()
                    },
                    { merge: true }
                );
            } catch (err) {
                console.error("Failed to upload attachment:", err);
                alert("Failed to upload attachment. Check console for details.");
            } finally {
                attachBtn.disabled = false;
            }
        }

        function setupAttach() {
            const btn = document.getElementById("attachBtn");
            const fileInput = document.getElementById("attachInput");
            btn.addEventListener("click", () => {
                if (!activeUserId) return;
                fileInput.click();
            });
            fileInput.addEventListener("change", async (e) => {
                const file = e.target.files && e.target.files[0];
                e.target.value = "";
                if (file) await sendAttachment(file);
            });
        }

        function setupSearch() {
            const input = document.getElementById("chatSearch");
            input.addEventListener("input", () => {
                listSearch = input.value.trim().toLowerCase();
                renderConversationList();
            });
        }

        document.addEventListener("firebase-auth-ready", () => {
            startThreadListener();
            setupReply();
            setupAttach();
            setupSearch();
        });
    </script>

</asp:Content>

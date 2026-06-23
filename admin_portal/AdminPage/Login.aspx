<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Login.aspx.cs" Inherits="AdminPage.Login" %>

<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <title>Admin Login - IRAMS</title>

    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@100..900&display=swap" rel="stylesheet" />

    <style>
        body { font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
        .login-bg {
            background-image: url('images/login-bg.jpg');
            background-size: cover;
            background-position: center;
        }
        .first-letter-yellow::first-letter {
            color: #FFC300;
            font-size: 120%;
        }
    </style>
</head>
<body class="bg-black text-white">
    <form id="form1" runat="server">
        <div class="min-h-screen grid grid-cols-1 md:grid-cols-2">

                <!-- left - big image and the text -->
            <div class="login-bg relative">
                <div class="absolute inset-0 bg-black/40"></div>
                <div class="relative h-full flex items-center justify-center p-10">
                    <div class="max-w-md text-white space-y-3 text-5xl md:text-6xl font-bold leading-tight">
                        <p class="first-letter-yellow">Intelligent</p>
                        <p class="first-letter-yellow">Roadside</p>
                        <p class="first-letter-yellow">Assistance</p>
                        <p class="first-letter-yellow">Management</p>
                        <p class="first-letter-yellow">System</p>
                        <p>(IRAMS)</p>
                    </div>
                </div>
            </div>

            <!-- right - login card -->
            <div class="flex items-center justify-center bg-black">
                <div class="w-full max-w-sm px-8">

                    <!-- logo block -->
                    <div class="w-70 h-70 mx-auto mb-8 flex items-center justify-center">
                        <img src="images/logoo.png" alt="IRAMS Logo" class="w-full h-full object-contain" />
                    </div>

                    <asp:Label ID="lblError" runat="server"
                               CssClass="block text-sm text-red-400 mb-3"></asp:Label>

                    <!-- Client-side error (Firebase Auth) -->
                    <div id="clientError" class="block text-sm text-red-400 mb-3"></div>

                    <!-- Hidden fields to pass Firebase data to server -->
                    <asp:HiddenField ID="hdnEmail" runat="server" />
                    <asp:HiddenField ID="hdnAdminName" runat="server" />
                    <asp:HiddenField ID="hdnAdminRole" runat="server" />

                    <!-- Username -->
                    <label class="block text-sm font-semibold mb-1">Email</label>
                    <div class="relative mb-4">
                        <span class="absolute left-3 top-2.5">
                            <i data-lucide="user" class="w-4 h-4 text-gray-400"></i>
                        </span>
                        <asp:TextBox ID="txtUsername" runat="server"
                            CssClass="w-full bg-white text-black rounded-md py-2 pl-9 pr-3 text-sm outline-none" />
                    </div>

                    <!-- Password -->
                    <label class="block text-sm font-semibold mb-1">Password</label>
                    <div class="relative mb-1">
                        <span class="absolute left-3 top-2.5">
                            <i data-lucide="lock" class="w-4 h-4 text-gray-400"></i>
                        </span>
                        <asp:TextBox ID="txtPassword" runat="server" TextMode="Password"
                            CssClass="w-full bg-white text-black rounded-md py-2 pl-9 pr-3 text-sm outline-none" />
                    </div>
                    <br /><br />
                    <!-- Login button — postback is blocked by JS; only fires after Firebase auth succeeds -->
                    <asp:Button ID="btnLogin" runat="server" Text="Login"
                        CssClass="w-full bg-yellow-500 hover:bg-yellow-600 text-black font-semibold py-2 rounded-full cursor-pointer mb-3"
                        OnClick="btnLogin_Click"
                        OnClientClick="handleLogin(); return false;"
                        UseSubmitBehavior="false" />
                </div>
            </div>
        </div>

        <script src="https://unpkg.com/lucide@latest"></script>
        <script> lucide.createIcons(); </script>

        <!-- Firebase SDKs for Authentication + Firestore lookup -->
        <script type="module">
            import { initializeApp } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-app.js";
            import { getAuth, signInWithEmailAndPassword } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
            import { getFirestore, collection, query, where, getDocs } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

            const firebaseConfig = {
                apiKey: "AIzaSyAMlwMv8JHIaiEnAhXMCVB8HItv8ovsVPA",
                authDomain: "iramsfyp.firebaseapp.com",
                databaseURL: "https://iramsfyp-default-rtdb.asia-southeast1.firebasedatabase.app",
                projectId: "iramsfyp",
                storageBucket: "iramsfyp.firebasestorage.app",
                messagingSenderId: "562587940412",
                appId: "1:562587940412:web:2a2471b2fd3dca4da5b539",
                measurementId: "G-KX04J3B1VQ"
            };

            const app = initializeApp(firebaseConfig);
            const auth = getAuth(app);
            const db = getFirestore(app);

            // Expose handleLogin globally so the ASP.NET button's OnClientClick can call it
            window.handleLogin = async function () {
                const errorDiv = document.getElementById("clientError");
                const btnLogin = document.getElementById("<%= btnLogin.ClientID %>");
                errorDiv.textContent = "";

                const email = document.getElementById("<%= txtUsername.ClientID %>").value.trim();
                const password = document.getElementById("<%= txtPassword.ClientID %>").value.trim();

                if (!email || !password) {
                    errorDiv.textContent = "Please enter both email and password.";
                    return;
                }

                // Disable button and show loading state
                btnLogin.disabled = true;
                btnLogin.value = "Signing in...";

                try {
                    // 1. Authenticate with Firebase
                    await signInWithEmailAndPassword(auth, email, password);

                    // 2. Look up AdminName and Role from the Admins collection
                    let adminName = "Admin";
                    let adminRole = "Admin";
                    try {
                        const q = query(collection(db, "Admins"), where("AdminEmail", "==", email));
                        const snap = await getDocs(q);
                        if (!snap.empty) {
                            const data = snap.docs[0].data();
                            adminName = data.AdminName || "Admin";
                            adminRole = data.Role || "Admin";
                        }
                    } catch (fsErr) {
                        console.warn("Admins lookup failed, using defaults:", fsErr);
                    }

                    // 3. Set hidden fields and trigger the server postback
                    document.getElementById("<%= hdnEmail.ClientID %>").value = email;
                    document.getElementById("<%= hdnAdminName.ClientID %>").value = adminName;
                    document.getElementById("<%= hdnAdminRole.ClientID %>").value = adminRole;
                    __doPostBack("<%= btnLogin.UniqueID %>", "");

                } catch (err) {
                    // Map Firebase error codes to user-friendly messages
                    const errorMap = {
                        "auth/invalid-email": "Invalid email address format.",
                        "auth/user-disabled": "This account has been disabled.",
                        "auth/user-not-found": "No account found with this email.",
                        "auth/wrong-password": "Incorrect password.",
                        "auth/invalid-credential": "Invalid email or password.",
                        "auth/too-many-requests": "Too many failed attempts. Please try again later."
                    };
                    errorDiv.textContent = errorMap[err.code] || err.message || "Login failed. Please try again.";
                    btnLogin.disabled = false;
                    btnLogin.value = "Login";
                }
            };
        </script>
    </form>
</body>
</html>

using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace AdminPage
{
    public partial class Login : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Clear server session when redirected from self-update logout
            if (!IsPostBack && Request.QueryString["action"] == "logout")
            {
                Session.Clear();
                Session.Abandon();
                return;
            }

            // If already logged in, go straight to dashboard
            if (!IsPostBack && Session["IsAdmin"] != null)
            {
                Response.Redirect("~/Dashboard.aspx");
            }
        }

        protected void btnLogin_Click(object sender, EventArgs e)
        {
            // Called via __doPostBack after Firebase Auth succeeds on the client.
            // The hidden fields carry the verified email and admin display name.
            string email = hdnEmail.Value.Trim();
            string adminName = hdnAdminName.Value.Trim();
            string adminRole = hdnAdminRole.Value.Trim();

            if (string.IsNullOrEmpty(email))
            {
                lblError.Text = "Authentication failed. Please try again.";
                return;
            }

            Session["IsAdmin"] = true;
            Session["AdminName"] = string.IsNullOrEmpty(adminName) ? "Admin" : adminName;
            Session["AdminEmail"] = email;
            Session["AdminRole"] = string.IsNullOrEmpty(adminRole) ? "Admin" : adminRole;

            Response.Redirect("~/Dashboard.aspx");
        }
    }
}
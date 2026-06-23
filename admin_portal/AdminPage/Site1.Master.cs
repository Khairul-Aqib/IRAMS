using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace AdminPage
{
    public partial class Site1 : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Prevent browser from caching POST responses (eliminates ERR_CACHE_MISS on Back)
            Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
            Response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1));

            string path = Request.Url.AbsolutePath.ToLower();

            // Only Login.aspx is public
            if (!path.EndsWith("login.aspx") && Session["IsAdmin"] == null)
            {
                Response.Redirect("~/Login.aspx");
                return;
            }

            // Set admin name in top-right
            if (!IsPostBack)
            {
                string name = Session["AdminName"] as string ?? "Admin";
                string role = Session["AdminRole"] as string ?? "Admin";
                lblAdminName.Text = name + " (" + role + ")";

                // Expose admin email to client-side JS for RBAC checks
                string email = Session["AdminEmail"] as string ?? "";
                Page.ClientScript.RegisterStartupScript(
                    this.GetType(), "adminEmail",
                    $"window.__adminEmail = '{HttpUtility.JavaScriptStringEncode(email)}';",
                    true);
            }
        }

        protected void Logout_Click(object sender, EventArgs e)
        {
            Session.Clear();
            Session.Abandon();
            Response.Redirect("~/Login.aspx");
        }
    }
}
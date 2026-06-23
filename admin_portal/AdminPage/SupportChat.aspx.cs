using System;
using System.Web.UI;

namespace AdminPage
{
    public partial class SupportChat : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["IsAdmin"] == null)
            {
                Response.Redirect("~/Login.aspx");
            }
        }
    }
}

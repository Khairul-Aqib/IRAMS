using System;
using System.IO;
using System.Web.UI;

namespace AdminPage
{
    public partial class ContractorEdit : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Page load logic if needed
        }

        // Web Method to handle file uploads
        [System.Web.Services.WebMethod]
        public static string SaveProfileImage(string contractorId, string base64Image, string fileName)
        {
            try
            {
                // Get the images folder path
                string imagesFolder = System.Web.Hosting.HostingEnvironment.MapPath("~/images");
                
                // Create the folder if it doesn't exist
                if (!Directory.Exists(imagesFolder))
                {
                    Directory.CreateDirectory(imagesFolder);
                }

                // Generate the filename: contractorId-filename
                string finalFileName = $"{contractorId}-{fileName}";
                string filePath = Path.Combine(imagesFolder, finalFileName);

                // Convert base64 to bytes and save
                // Remove the data:image prefix if present
                if (base64Image.Contains(","))
                {
                    base64Image = base64Image.Split(',')[1];
                }

                byte[] imageBytes = Convert.FromBase64String(base64Image);
                File.WriteAllBytes(filePath, imageBytes);

                return finalFileName; // Return just the filename to store in Firebase
            }
            catch (Exception ex)
            {
                return "ERROR: " + ex.Message;
            }
        }
    }
}

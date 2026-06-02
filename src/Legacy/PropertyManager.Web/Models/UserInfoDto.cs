namespace PropertyManager.Web.Models
{
    public class UserInfoDto
    {
        public string UserId { get; set; }
        public string UserName { get; set; }
        public string DisplayName { get; set; }
        public string Role { get; set; }
        public bool IsAuthenticated { get; set; }
    }
}

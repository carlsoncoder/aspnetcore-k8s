namespace aspnetcore_k8s.Controllers
{
    using Microsoft.AspNetCore.Http;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;    

    [ApiController]
    [Route("[controller]")]
    public class PodInfoController : ControllerBase
    {
        #region Fields

        private readonly ILogger<PodInfoController> _logger;

        private readonly IHttpContextAccessor _context;

        #endregion

        #region Constructors

        public PodInfoController(ILogger<PodInfoController> logger, IHttpContextAccessor context)
        {
            this._logger = logger;
            this._context = context;
        }

        #endregion

        #region Methods

        [HttpGet]
        public PodInfo Get()
        {
            var httpRequest = this._context.HttpContext.Request;
            this._logger.LogError("Error accessing PodInfoController");
            this._logger.LogWarning("Warning accessing PodInfoController");
            this._logger.LogInformation("Information about accessing PodInfoController");
            return new PodInfo(httpRequest);
        }

        #endregion
    }
}
namespace aspnetcore_k8s.Controllers
{
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;

    [ApiController]
    [Route("[controller]")]
    public class PodInfoController : ControllerBase
    {
        #region Fields

        private readonly ILogger<PodInfoController> _logger;

        public PodInfoController(ILogger<PodInfoController> logger)
        {
            this._logger = logger;
        }

        #endregion

        #region Methods

        [HttpGet]
        public PodInfo Get()
        {            
            return new PodInfo();
        }

        #endregion
    }
}
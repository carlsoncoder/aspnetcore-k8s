namespace aspnetcore_k8s.Controllers
{
    using System;
    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Extensions.Logging;

    [ApiController]
    [Route("[controller]")]
    public class HealthZController : ControllerBase
    {
        #region Fields

        private readonly ILogger<HealthZController> _logger;

        #endregion

        #region Constructors
        
        public HealthZController(ILogger<HealthZController> logger)
        {
            this._logger = logger;
        }

        #endregion

        #region Methods

        [HttpGet]
        public object Get()
        {            
            return new { Status = "OK", DateTime = DateTime.UtcNow };
        }

        #endregion
    }
}
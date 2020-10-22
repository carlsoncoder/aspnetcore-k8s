namespace aspnetcore_k8s
{
    using System;
    using Microsoft.AspNetCore.Http;


    public class PodInfo
    {
        #region Constructors

        public PodInfo(HttpRequest httpRequest)
        {
            this.Timestamp = DateTime.UtcNow;
            this.NodeName = Environment.GetEnvironmentVariable("NODE_NAME");
            this.PodName = Environment.GetEnvironmentVariable("POD_NAME");
            this.ApplicationName = Environment.GetEnvironmentVariable("CUSTOM_APPLICATION_NAME");

            this.Host = httpRequest.Headers["Host"];
            this.Path = httpRequest.Path;
        }

        #endregion

        #region Properties

        public DateTime Timestamp
        {
            get;
            private set;
        }

        public string NodeName
        {
            get;
            private set;
        }

        public string PodName
        {
            get;
            private set;
        }

        public string ApplicationName
        {
            get;
            private set;
        }

        public string Host
        {
            get;
            private set;
        }

        public string Path
        {
            get;
            private set;
        }

        #endregion
    }
}
namespace aspnetcore_k8s
{
    using System;

    public class PodInfo
    {
        #region Constructors

        public PodInfo()
        {
            this.Timestamp = DateTime.UtcNow;
            this.NodeName = Environment.GetEnvironmentVariable("NODE_NAME");
            this.PodName = Environment.GetEnvironmentVariable("POD_NAME");
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

        #endregion
    }
}
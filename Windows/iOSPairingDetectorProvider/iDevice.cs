using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace iOSPairingDetectorProvider
{
    public class iDevice
    {
        public string HostId { get; set; }

        public string BUID { get; set; }

        public string WiFiMACAddress { get; set; }

        public string TrustedFilePath { get; set; }

        public string BlueToothMACddress
        {
            get
            {
                if (!String.IsNullOrEmpty(this.WiFiMACAddress))
                {
                    UInt64 macAsNumber = Convert.ToUInt64(this.WiFiMACAddress.Replace(":", ""), 16);
                    macAsNumber++;
                    string blueMacAddress = macAsNumber.ToString("X12");
                    return Regex.Replace(blueMacAddress, ".{2}", "$0:").Trim(':');
                }
                else
                {
                    return String.Empty;
                }
            }
        }

        public string UDID { get; set; }
    }
}

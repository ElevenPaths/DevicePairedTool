using Microsoft.Win32;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace iOSPairingDetectorProvider
{
    public class iDeviceProvider
    {
        public static IEnumerable<iDevice> List()
        {
            string[] plistFiles = Directory.GetFiles(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData) + @"\Apple\Lockdown", "*.plist").Where(f => Path.GetFileNameWithoutExtension(f).Length == 40).ToArray();
            ConcurrentBag<iDevice> devices = new ConcurrentBag<iDevice>();

            Parallel.ForEach(plistFiles, (f) =>
             {
                 PList plistFile = new PList(new Uri(f));
                 string udid = Path.GetFileNameWithoutExtension(f);
                 devices.Add(new iDevice()
                 {
                     BUID = plistFile["SystemBUID"],
                     HostId = plistFile["HostID"],
                     UDID = udid,
                     WiFiMACAddress = ((string)plistFile["WiFiMACAddress"]).ToUpper(),
                     TrustedFilePath = f
                 });
             });

            return devices;
        }
    }
}

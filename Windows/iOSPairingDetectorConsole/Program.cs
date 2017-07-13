using iOSPairingDetectorProvider;
using System;

namespace iOSPairingDetectorConsole
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("UDID\tWIFI-MAC");
            Console.WriteLine(new string('-', Console.WindowWidth));
            foreach (var device in iDeviceProvider.List())
            {
                Console.WriteLine(String.Join("\t", device.UDID, device.WiFiMACAddress));
            }
        }
    }
}

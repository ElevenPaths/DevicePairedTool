using FirstFloor.ModernUI.Windows.Controls;
using iOSPairingDetectorProvider;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Windows;

namespace iOSPairingDetectorGUI
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : ModernWindow
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        private void Window_Loaded(object sender, RoutedEventArgs e)
        {
            this.RefreshDevices();
        }

        private void Button_Click(object sender, RoutedEventArgs e)
        {
            iDevice selectedDevice = ((FrameworkElement)sender).DataContext as iDevice;
            if (selectedDevice != null && File.Exists(selectedDevice.TrustedFilePath))
            {
                File.Delete(selectedDevice.TrustedFilePath);
                this.RefreshDevices();
            }
        }

        private void RefreshDevices()
        {
            this.dtgDevices.DataContext = new ObservableCollection<iDevice>(iDeviceProvider.List());
        }

        private void refreshButton_Click(object sender, RoutedEventArgs e)
        {
            this.RefreshDevices();
        }

        private void closeButton_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void Hyperlink_RequestNavigate(object sender, System.Windows.Navigation.RequestNavigateEventArgs e)
        {
            Process.Start(new ProcessStartInfo(e.Uri.AbsoluteUri));
            e.Handled = true;
        }
    }
}

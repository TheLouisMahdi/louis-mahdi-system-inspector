using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("LouisMahdi System Inspector")]
[assembly: AssemblyDescription("Read-only offline Windows hardware and operating-system inventory")]
[assembly: AssemblyCompany("LouisMahdi")]
[assembly: AssemblyProduct("LouisMahdi System Inspector")]
[assembly: AssemblyCopyright("Developed by LouisMahdi | github.com/TheLouisMahdi")]
[assembly: AssemblyVersion("2.2.0.0")]
[assembly: AssemblyFileVersion("2.2.0.0")]
[assembly: AssemblyInformationalVersion("2.2.0")]

namespace LouisMahdi.SystemInspector.Host
{
    internal static class Program
    {
        private const string SourceResourceName = "LouisMahdi.SystemInspector.Source";
        private const string IconResourceName = "LouisMahdi.SystemInspector.Icon";
        private const string ExpectedSourceSha256 = "__SOURCE_SHA256__";
        private const uint MbIconError = 0x00000010;
        private const uint MbOk = 0x00000000;

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int MessageBox(IntPtr windowHandle, string text, string caption, uint type);

        [STAThread]
        private static int Main(string[] args)
        {
            bool selfTest = HasArgument(args, "--launcher-self-test");
            bool noGui = HasArgument(args, "--nogui") || HasArgument(args, "-NoGui") || selfTest;
            string tempDirectory = null;
            try
            {
                byte[] sourceBytes = ReadResource(SourceResourceName);
                VerifySource(sourceBytes);
                string powershellPath = FindWindowsPowerShell();
                if (selfTest) return 0;
                tempDirectory = CreateTemporaryDirectory();
                string sourcePath = Path.Combine(tempDirectory, "LouisMahdi.SystemInspector.ps1");
                string iconPath = Path.Combine(tempDirectory, "LouisMahdi_System_Inspector.ico");
                File.WriteAllBytes(sourcePath, sourceBytes);
                byte[] iconBytes = TryReadResource(IconResourceName);
                if (iconBytes != null && iconBytes.Length > 0) File.WriteAllBytes(iconPath, iconBytes);
                ProcessResult result = RunPowerShell(powershellPath, sourcePath, File.Exists(iconPath) ? iconPath : null, args);
                if (result.ExitCode != 0)
                {
                    string details = BuildFailureDetails(result);
                    WriteDiagnostic(details);
                    if (!noGui) ShowError("LouisMahdi System Inspector could not start.\r\n\r\n" + details + "\r\n\r\nThe application made no system changes.");
                }
                return result.ExitCode;
            }
            catch (Exception exception)
            {
                string details = exception.GetType().FullName + ": " + exception.Message;
                WriteDiagnostic(details);
                if (!noGui) ShowError("LouisMahdi System Inspector could not start.\r\n\r\n" + Limit(details, 1800) + "\r\n\r\nThe application made no system changes.");
                return 1;
            }
            finally
            {
                DeleteTemporaryDirectory(tempDirectory);
            }
        }

        private static byte[] ReadResource(string resourceName)
        {
            byte[] bytes = TryReadResource(resourceName);
            if (bytes == null || bytes.Length == 0) throw new InvalidDataException("The embedded application resource is missing or empty: " + resourceName);
            return bytes;
        }

        private static byte[] TryReadResource(string resourceName)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream stream = assembly.GetManifestResourceStream(resourceName))
            {
                if (stream == null) return null;
                using (MemoryStream memory = new MemoryStream())
                {
                    stream.CopyTo(memory);
                    return memory.ToArray();
                }
            }
        }

        private static void VerifySource(byte[] sourceBytes)
        {
            string actualHash;
            using (SHA256 algorithm = SHA256.Create())
            {
                actualHash = ToHex(algorithm.ComputeHash(sourceBytes));
            }
            if (!actualHash.Equals(ExpectedSourceSha256, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("The embedded PowerShell source failed its integrity check.");
            }
            if (sourceBytes.Length < 128) throw new InvalidDataException("The embedded PowerShell source is unexpectedly short.");
            string prefix = Encoding.UTF8.GetString(sourceBytes, 0, Math.Min(sourceBytes.Length, 512));
            if (prefix.IndexOf("#requires -version 5.1", StringComparison.OrdinalIgnoreCase) < 0)
            {
                throw new InvalidDataException("The embedded PowerShell source header is invalid.");
            }
        }

        private static string ToHex(byte[] bytes)
        {
            StringBuilder builder = new StringBuilder(bytes.Length * 2);
            for (int index = 0; index < bytes.Length; index++) builder.Append(bytes[index].ToString("x2"));
            return builder.ToString();
        }

        private static string FindWindowsPowerShell()
        {
            string windowsDirectory = Environment.GetEnvironmentVariable("WINDIR");
            if (String.IsNullOrWhiteSpace(windowsDirectory)) windowsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            List<string> candidates = new List<string>();
            if (!String.IsNullOrWhiteSpace(windowsDirectory))
            {
                if (Environment.Is64BitOperatingSystem && !Environment.Is64BitProcess)
                {
                    candidates.Add(Path.Combine(windowsDirectory, "Sysnative", "WindowsPowerShell", "v1.0", "powershell.exe"));
                }
                candidates.Add(Path.Combine(windowsDirectory, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"));
                candidates.Add(Path.Combine(windowsDirectory, "SysWOW64", "WindowsPowerShell", "v1.0", "powershell.exe"));
            }
            for (int index = 0; index < candidates.Count; index++)
            {
                if (File.Exists(candidates[index])) return candidates[index];
            }
            string pathResult = FindOnPath("powershell.exe");
            if (!String.IsNullOrWhiteSpace(pathResult)) return pathResult;
            throw new FileNotFoundException("Windows PowerShell 5.1 could not be located. Windows 10, Windows 11, and Windows Server 2016 or later normally include it.");
        }

        private static string FindOnPath(string fileName)
        {
            string pathValue = Environment.GetEnvironmentVariable("PATH") ?? String.Empty;
            string[] directories = pathValue.Split(new char[] { Path.PathSeparator }, StringSplitOptions.RemoveEmptyEntries);
            for (int index = 0; index < directories.Length; index++)
            {
                try
                {
                    string candidate = Path.Combine(directories[index].Trim(), fileName);
                    if (File.Exists(candidate)) return candidate;
                }
                catch
                {
                }
            }
            return null;
        }

        private static ProcessResult RunPowerShell(string powershellPath, string sourcePath, string iconPath, string[] args)
        {
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = powershellPath;
            startInfo.Arguments = BuildPowerShellArguments(sourcePath, args);
            startInfo.WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory;
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;
            if (!String.IsNullOrWhiteSpace(iconPath)) startInfo.EnvironmentVariables["LOUISMAHDI_ICON_PATH"] = iconPath;
            startInfo.EnvironmentVariables["LOUISMAHDI_LAUNCHER_VERSION"] = "2.2.0";
            startInfo.EnvironmentVariables["LOUISMAHDI_LAUNCHER_ARCHITECTURE"] = GetProcessArchitecture();
            StringBuilder output = new StringBuilder();
            StringBuilder error = new StringBuilder();
            using (Process process = new Process())
            {
                process.StartInfo = startInfo;
                process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs eventArgs)
                {
                    if (eventArgs.Data != null) lock (output) output.AppendLine(eventArgs.Data);
                };
                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs eventArgs)
                {
                    if (eventArgs.Data != null) lock (error) error.AppendLine(eventArgs.Data);
                };
                if (!process.Start()) throw new InvalidOperationException("Windows PowerShell could not be started.");
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();
                process.WaitForExit();
                process.WaitForExit();
                return new ProcessResult(process.ExitCode, output.ToString(), error.ToString());
            }
        }

        private static string BuildPowerShellArguments(string sourcePath, string[] args)
        {
            List<string> values = new List<string>();
            values.Add("-NoLogo");
            values.Add("-NoProfile");
            values.Add("-ExecutionPolicy");
            values.Add("Bypass");
            values.Add("-STA");
            values.Add("-File");
            values.Add(sourcePath);
            if (args != null)
            {
                for (int index = 0; index < args.Length; index++)
                {
                    string argument = args[index] ?? String.Empty;
                    if (argument.Equals("--launcher-self-test", StringComparison.OrdinalIgnoreCase)) continue;
                    if (argument.Equals("--nogui", StringComparison.OrdinalIgnoreCase)) values.Add("-NoGui");
                    else if (argument.Equals("--extended", StringComparison.OrdinalIgnoreCase))
                    {
                        values.Add("-Mode");
                        values.Add("Extended");
                    }
                    else if (argument.Equals("--unredacted", StringComparison.OrdinalIgnoreCase)) values.Add("-DisablePrivacy");
                    else if (argument.Equals("--html", StringComparison.OrdinalIgnoreCase)) values.Add("-IncludeHtml");
                    else if (argument.Equals("--open", StringComparison.OrdinalIgnoreCase)) values.Add("-OpenOutput");
                    else if (argument.Equals("--retain-diagnostics", StringComparison.OrdinalIgnoreCase)) values.Add("-RetainDiagnostics");
                    else if (argument.StartsWith("--output=", StringComparison.OrdinalIgnoreCase))
                    {
                        values.Add("-OutputDirectory");
                        values.Add(argument.Substring(9).Trim('"'));
                    }
                    else values.Add(argument);
                }
            }
            StringBuilder commandLine = new StringBuilder();
            for (int index = 0; index < values.Count; index++)
            {
                if (index > 0) commandLine.Append(' ');
                commandLine.Append(QuoteArgument(values[index]));
            }
            return commandLine.ToString();
        }

        private static string QuoteArgument(string value)
        {
            if (value == null) value = String.Empty;
            if (value.Length > 0 && value.IndexOfAny(new char[] { ' ', '\t', '\r', '\n', '"' }) < 0) return value;
            StringBuilder builder = new StringBuilder();
            builder.Append('"');
            int slashCount = 0;
            for (int index = 0; index < value.Length; index++)
            {
                char character = value[index];
                if (character == '\\')
                {
                    slashCount++;
                    continue;
                }
                if (character == '"')
                {
                    builder.Append('\\', slashCount * 2 + 1);
                    builder.Append('"');
                    slashCount = 0;
                    continue;
                }
                if (slashCount > 0)
                {
                    builder.Append('\\', slashCount);
                    slashCount = 0;
                }
                builder.Append(character);
            }
            if (slashCount > 0) builder.Append('\\', slashCount * 2);
            builder.Append('"');
            return builder.ToString();
        }

        private static string CreateTemporaryDirectory()
        {
            string root = Path.Combine(Path.GetTempPath(), "LouisMahdi_SystemInspector");
            Directory.CreateDirectory(root);
            string directory = Path.Combine(root, Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory);
            return directory;
        }

        private static void DeleteTemporaryDirectory(string directory)
        {
            if (String.IsNullOrWhiteSpace(directory)) return;
            for (int attempt = 0; attempt < 4; attempt++)
            {
                try
                {
                    if (Directory.Exists(directory)) Directory.Delete(directory, true);
                    return;
                }
                catch
                {
                    Thread.Sleep(150 * (attempt + 1));
                }
            }
        }

        private static bool HasArgument(string[] args, string expected)
        {
            if (args == null) return false;
            for (int index = 0; index < args.Length; index++)
            {
                if (String.Equals(args[index], expected, StringComparison.OrdinalIgnoreCase)) return true;
            }
            return false;
        }

        private static string BuildFailureDetails(ProcessResult result)
        {
            string error = (result.ErrorText ?? String.Empty).Trim();
            string output = (result.OutputText ?? String.Empty).Trim();
            if (!String.IsNullOrWhiteSpace(error)) return Limit(error, 1800);
            if (!String.IsNullOrWhiteSpace(output)) return Limit(output, 1800);
            return "Windows PowerShell exited with code " + result.ExitCode + ".";
        }

        private static string GetProcessArchitecture()
        {
            string os = Environment.Is64BitOperatingSystem ? "64-bit OS" : "32-bit OS";
            string process = Environment.Is64BitProcess ? "64-bit process" : "32-bit process";
            return os + ", " + process;
        }

        private static void ShowError(string message)
        {
            try
            {
                MessageBox(IntPtr.Zero, Limit(message, 2000), "LouisMahdi System Inspector", MbOk | MbIconError);
            }
            catch
            {
            }
        }

        private static void WriteDiagnostic(string message)
        {
            try
            {
                string path = Path.Combine(Path.GetTempPath(), "LouisMahdi_SystemInspector_LastError.txt");
                File.WriteAllText(path, DateTimeOffset.Now.ToString("o") + Environment.NewLine + message, Encoding.UTF8);
            }
            catch
            {
            }
        }

        private static string Limit(string value, int maximumLength)
        {
            if (String.IsNullOrEmpty(value)) return "Unspecified startup failure.";
            if (value.Length <= maximumLength) return value;
            return value.Substring(0, maximumLength) + "...";
        }

        private sealed class ProcessResult
        {
            internal readonly int ExitCode;
            internal readonly string OutputText;
            internal readonly string ErrorText;

            internal ProcessResult(int exitCode, string outputText, string errorText)
            {
                ExitCode = exitCode;
                OutputText = outputText;
                ErrorText = errorText;
            }
        }
    }
}
